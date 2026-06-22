//
//  AirQuality.swift
//  OpenMeteoKit
//
//  Open-Meteo's UV index AND air-quality (US AQI, PM2.5) live on the separate
//  Air-Quality API (air-quality-api.open-meteo.com), not the forecast endpoint,
//  and are location-based (model-independent). One request serves both the app's
//  UV overlay and its air-quality feature (PM2.5 is the wildfire-smoke signal).
//

import Foundation

public struct AirQualityForecast: Sendable {
  public struct Hour: Sendable {
    public let date: Date
    public let uvIndex: Double?
    public let usAQI: Int?
    public let europeanAQI: Int?
    /// Canadian Air Quality Health Index (1–10+), computed from O3/NO2/PM2.5 since
    /// Open-Meteo doesn't expose it directly. nil when components are missing.
    public let canadianAQHI: Int?
    /// PM2.5 in µg/m³ — the fine-particulate (wildfire smoke) measure.
    public let pm2_5: Double?
  }
  public let utcOffsetSeconds: Int
  public let timezone: String
  public let hourly: [Hour]
}

extension OpenMeteoClient {

  public static let defaultAirQualityBaseURL = "https://air-quality-api.open-meteo.com/v1/air-quality"

  /// Fetch hourly UV index, US AQI, and PM2.5 for a location. These are
  /// model-independent (sun + atmosphere), so this is a single light request
  /// regardless of the selected forecast model. Horizon is capped at the AQ
  /// API's ~7 days.
  public func fetchAirQuality(
    latitude: Double,
    longitude: Double,
    forecastDays: Int = 7,
    airQualityBaseURL: String = OpenMeteoClient.defaultAirQualityBaseURL
  ) async throws -> AirQualityForecast {
    guard var components = URLComponents(string: airQualityBaseURL) else {
      throw OpenMeteoError.invalidURL
    }
    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      // us_aqi + european_aqi are returned directly; canadian AQHI is computed
      // from ozone/nitrogen_dioxide/pm2_5 (Open-Meteo has no AQHI field).
      URLQueryItem(name: "hourly", value: "uv_index,us_aqi,european_aqi,pm2_5,ozone,nitrogen_dioxide"),
      URLQueryItem(name: "forecast_days", value: String(min(forecastDays, 7))),
      URLQueryItem(name: "timezone", value: "auto")
    ]
    guard let baseURL = components.url else { throw OpenMeteoError.invalidURL }
    let url = applyingAPIKeyPublic(to: baseURL)

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
      throw OpenMeteoError.invalidResponse
    }
    do {
      let raw = try JSONDecoder().decode(RawAirQualityResponse.self, from: data)
      return Self.transform(raw)
    } catch {
      throw OpenMeteoError.decodingError(error)
    }
  }

  private static func transform(_ raw: RawAirQualityResponse) -> AirQualityForecast {
    // `timezone=auto` → local time strings; parse in the location's zone.
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TimeZone(secondsFromGMT: raw.utcOffsetSeconds) ?? TimeZone(abbreviation: "GMT")

    func at<T>(_ array: [T?]?, _ index: Int) -> T? {
      guard let array, array.indices.contains(index) else { return nil }
      return array[index]
    }

    var hours: [AirQualityForecast.Hour] = []
    for (index, timeString) in raw.hourly.time.enumerated() {
      guard let date = formatter.date(from: timeString) else { continue }
      let pm = at(raw.hourly.pm2_5, index)
      hours.append(.init(
        date: date,
        uvIndex: at(raw.hourly.uvIndex, index),
        usAQI: at(raw.hourly.usAQI, index).map(Int.init),
        europeanAQI: at(raw.hourly.europeanAQI, index).map(Int.init),
        canadianAQHI: aqhi(ozone: at(raw.hourly.ozone, index),
                           no2: at(raw.hourly.no2, index),
                           pm2_5: pm),
        pm2_5: pm
      ))
    }
    return AirQualityForecast(utcOffsetSeconds: raw.utcOffsetSeconds, timezone: raw.timezone, hourly: hours)
  }

  /// Canadian Air Quality Health Index from O3/NO2 (µg/m³ → ppb) + PM2.5 (µg/m³),
  /// using the ECCC formula on instantaneous values. Returns nil if any is missing.
  /// AQHI = (1000/10.4) · [ (e^(0.000537·O3ppb)−1) + (e^(0.000871·NO2ppb)−1) + (e^(0.000487·PM2.5)−1) ]
  private static func aqhi(ozone: Double?, no2: Double?, pm2_5: Double?) -> Int? {
    guard let ozone, let no2, let pm2_5 else { return nil }
    let o3ppb = ozone / 1.96        // O3: 1 ppb ≈ 1.96 µg/m³
    let no2ppb = no2 / 1.88         // NO2: 1 ppb ≈ 1.88 µg/m³
    let value = (1000.0 / 10.4) * ((exp(0.000537 * o3ppb) - 1)
                                   + (exp(0.000871 * no2ppb) - 1)
                                   + (exp(0.000487 * pm2_5) - 1))
    return max(1, Int(value.rounded()))
  }
}

private struct RawAirQualityResponse: Decodable {
  let utcOffsetSeconds: Int
  let timezone: String
  let hourly: Hourly

  struct Hourly: Decodable {
    let time: [String]
    let uvIndex: [Double?]?
    let usAQI: [Double?]?
    let europeanAQI: [Double?]?
    let pm2_5: [Double?]?
    let ozone: [Double?]?
    let no2: [Double?]?
    enum CodingKeys: String, CodingKey {
      case time
      case uvIndex = "uv_index"
      case usAQI = "us_aqi"
      case europeanAQI = "european_aqi"
      case pm2_5 = "pm2_5"
      case ozone
      case no2 = "nitrogen_dioxide"
    }
  }

  enum CodingKeys: String, CodingKey {
    case timezone
    case utcOffsetSeconds = "utc_offset_seconds"
    case hourly
  }
}
