//
//  Ensemble.swift
//  OpenMeteoKit
//
//  Open-Meteo ENSEMBLE forecast support.
//
//  The ensemble API lives on a DIFFERENT host than the deterministic forecast
//  API: `https://ensemble-api.open-meteo.com/v1/ensemble`. For a single-model
//  request the response `hourly` block carries the control run under the BARE
//  variable name (e.g. `temperature_2m`) and each perturbed member under
//  `temperature_2m_member01 … _memberNN` (zero-padded, starting at 01). The
//  static-CodingKeys decoder used for deterministic forecasts cannot express
//  this, so we decode the `hourly` block into `[String: [Double?]]` + `time`.
//

import Foundation

// MARK: - Ensemble models

/// Ensemble systems available on the ensemble-api host. These ids differ from
/// the deterministic `WeatherModel` ids (e.g. GEFS is `gfs025`, not
/// `gfs_seamless`), so they get their own enum.
public enum EnsembleModel: String, CaseIterable, Sendable {
  /// NOAA GEFS 0.25° — 31 series (1 control + 30 members), 10-day horizon.
  case gfs025
  /// ECMWF IFS-ENS 0.25° — 51 series, 15-day horizon.
  case ecmwfIfs025 = "ecmwf_ifs025"
  /// DWD ICON-EPS (seamless/global) — 40 series, ~7.5-day horizon, hourly.
  case iconSeamless = "icon_seamless"
  /// CMC GEPS — 21 series, 16-day horizon.
  case gemGlobal = "gem_global"
}

// MARK: - Ensemble variables

/// A single surface variable to request from the ensemble API. Only ONE variable
/// is requested per call: each `_memberNN` series counts as a billed variable, so
/// member counts already multiply the call cost past the metering threshold.
public enum EnsembleVariable: String, CaseIterable, Sendable {
  case temperature2m = "temperature_2m"
  case windSpeed10m = "wind_speed_10m"
  case precipitation = "precipitation"

  /// Whether this variable is a wind speed (drives `wind_speed_unit=kn`).
  var isWind: Bool {
    switch self {
    case .windSpeed10m: return true
    case .temperature2m, .precipitation: return false
    }
  }
}

// MARK: - Ensemble response

/// Decoded ensemble forecast for a single variable at a single location.
///
/// - `control` is the bare control-run series (one value per timestep).
/// - `members` is `[memberIndex][timeIndex]` — the perturbed members, sorted
///   numerically by their `_memberNN` suffix.
public struct EnsembleResponse: Sendable {
  public let time: [Date]
  public let control: [Double?]
  public let members: [[Double?]]
  public let unit: String?

  public init(time: [Date], control: [Double?], members: [[Double?]], unit: String?) {
    self.time = time
    self.control = control
    self.members = members
    self.unit = unit
  }

  /// Computes interpolated quantiles over the non-nil member values at each
  /// timestep. The control run is intentionally excluded so the percentiles
  /// describe the spread of the perturbed ensemble.
  ///
  /// - Parameter p: Percentiles in 0...100 (e.g. `[10, 25, 50, 75, 90]`).
  /// - Returns: `[percentileIndex][timeIndex]`. A timestep with no non-nil
  ///   member values yields `nil` for every requested percentile.
  public func percentiles(_ p: [Double]) -> [[Double?]] {
    let timeCount = time.count
    var result = [[Double?]](repeating: [Double?](repeating: nil, count: timeCount), count: p.count)

    for t in 0..<timeCount {
      var values: [Double] = []
      for member in members where member.indices.contains(t) {
        if let v = member[t] { values.append(v) }
      }
      guard !values.isEmpty else { continue }
      values.sort()
      for (pi, percentile) in p.enumerated() {
        result[pi][t] = Self.interpolatedQuantile(sorted: values, percentile: percentile)
      }
    }
    return result
  }

  /// Linear-interpolation ("R-7" / numpy default) quantile over a sorted array.
  static func interpolatedQuantile(sorted values: [Double], percentile: Double) -> Double {
    guard let first = values.first else { return .nan }
    if values.count == 1 { return first }
    let clamped = min(max(percentile, 0), 100)
    let rank = (clamped / 100.0) * Double(values.count - 1)
    let lower = Int(rank.rounded(.down))
    let upper = Int(rank.rounded(.up))
    if lower == upper { return values[lower] }
    let weight = rank - Double(lower)
    return values[lower] * (1 - weight) + values[upper] * weight
  }
}

// MARK: - Raw decoding

/// Decodes the ensemble payload into `time` + a `[fieldName: [Double?]]` map,
/// mirroring the deterministic client's dynamic-key approach.
struct RawEnsembleResponse: Decodable {
  let timezone: String
  let unit: String?
  let time: [String]
  let fields: [String: [Double?]]

  enum CodingKeys: String, CodingKey {
    case timezone
    case hourly
    case hourlyUnits = "hourly_units"
  }

  private struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    timezone = (try? container.decode(String.self, forKey: .timezone)) ?? "GMT"

    let block = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .hourly)
    var time: [String] = []
    var fields: [String: [Double?]] = [:]
    for key in block.allKeys {
      if key.stringValue == "time" {
        time = try block.decode([String].self, forKey: key)
      } else {
        fields[key.stringValue] = try block.decode([Double?].self, forKey: key)
      }
    }
    self.time = time
    self.fields = fields

    // Unit for the bare variable, if a units block is present.
    if container.contains(.hourlyUnits) {
      let unitsBlock = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .hourlyUnits)
      var found: String?
      for key in unitsBlock.allKeys where key.stringValue != "time" && !key.stringValue.contains("_member") {
        found = try? unitsBlock.decode(String.self, forKey: key)
      }
      unit = found
    } else {
      unit = nil
    }
  }
}

extension EnsembleResponse {
  /// Builds an `EnsembleResponse` for `variable` from a decoded raw payload.
  /// Control = the bare variable key; members = keys matching
  /// `^<variable>_member\d+$`, sorted numerically by member number.
  static func from(raw: RawEnsembleResponse, variable: EnsembleVariable) -> EnsembleResponse {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TimeZone(identifier: raw.timezone) ?? TimeZone(abbreviation: "GMT")

    let dates = raw.time.map { formatter.date(from: $0) ?? Date() }

    let base = variable.rawValue
    let control = raw.fields[base] ?? [Double?](repeating: nil, count: dates.count)

    let memberPrefix = "\(base)_member"
    let memberKeys = raw.fields.keys
      .filter { $0.hasPrefix(memberPrefix) && Int($0.dropFirst(memberPrefix.count)) != nil }
      .sorted { (lhs, rhs) in
        let l = Int(lhs.dropFirst(memberPrefix.count)) ?? 0
        let r = Int(rhs.dropFirst(memberPrefix.count)) ?? 0
        return l < r
      }
    let members = memberKeys.map { raw.fields[$0] ?? [] }

    return EnsembleResponse(time: dates, control: control, members: members, unit: raw.unit)
  }
}

// MARK: - Client

public extension OpenMeteoClient {
  /// Default host + path for the ensemble API. Distinct from the deterministic
  /// forecast host; the deterministic host does not serve ensemble members.
  static let defaultEnsembleBaseURL = "https://ensemble-api.open-meteo.com/v1/ensemble"

  /// Fetches an ensemble forecast for a SINGLE variable from a SINGLE model.
  ///
  /// - Parameters:
  ///   - latitude: Latitude in degrees.
  ///   - longitude: Longitude in degrees.
  ///   - model: The ensemble system (default GEFS 0.25°).
  ///   - variable: The single surface variable to request.
  ///   - forecastDays: Number of forecast days.
  ///   - ensembleBaseURL: Override the ensemble endpoint (default the public host).
  func fetchEnsemble(
    latitude: Double,
    longitude: Double,
    model: EnsembleModel = .gfs025,
    variable: EnsembleVariable = .temperature2m,
    forecastDays: Int = 7,
    ensembleBaseURL: String = OpenMeteoClient.defaultEnsembleBaseURL
  ) async throws -> EnsembleResponse {
    var components = URLComponents(string: ensembleBaseURL)!
    var queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "models", value: model.rawValue),
      URLQueryItem(name: "hourly", value: variable.rawValue),
      URLQueryItem(name: "forecast_days", value: String(forecastDays)),
      URLQueryItem(name: "timezone", value: "auto")
    ]
    if variable.isWind {
      queryItems.append(URLQueryItem(name: "wind_speed_unit", value: WindSpeedUnit.knots.rawValue))
    }
    components.queryItems = queryItems

    let url = applyingAPIKeyPublic(to: components.url!)

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          200...299 ~= httpResponse.statusCode else {
      throw OpenMeteoError.invalidResponse
    }

    do {
      let raw = try JSONDecoder().decode(RawEnsembleResponse.self, from: data)
      return EnsembleResponse.from(raw: raw, variable: variable)
    } catch {
      throw OpenMeteoError.decodingError(error)
    }
  }
}
