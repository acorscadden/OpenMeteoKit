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
      URLQueryItem(name: "hourly", value: "uv_index,us_aqi,pm2_5"),
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
      hours.append(.init(
        date: date,
        uvIndex: at(raw.hourly.uvIndex, index),
        usAQI: at(raw.hourly.usAQI, index).map(Int.init),
        pm2_5: at(raw.hourly.pm2_5, index)
      ))
    }
    return AirQualityForecast(utcOffsetSeconds: raw.utcOffsetSeconds, timezone: raw.timezone, hourly: hours)
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
    let pm2_5: [Double?]?
    enum CodingKeys: String, CodingKey {
      case time
      case uvIndex = "uv_index"
      case usAQI = "us_aqi"
      case pm2_5 = "pm2_5"
    }
  }

  enum CodingKeys: String, CodingKey {
    case timezone
    case utcOffsetSeconds = "utc_offset_seconds"
    case hourly
  }
}
