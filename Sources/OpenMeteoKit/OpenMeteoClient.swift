//
//  Client.swift
//  OpenMeteoKit
//
//  Created by Adrian Corscadden on 2025-06-18.
//

import Foundation

public struct OpenMeteoClient {
  private let baseURL = "https://api.open-meteo.com/v1"
  private let session = URLSession.shared

  public init() {}

  public func fetchWeatherData(
    latitude: Double,
    longitude: Double,
    models: [WeatherModel] = [.ecmwfIfs025, .iconSeamless],
    windSpeedUnit: WindSpeedUnit = .knots
  ) async throws -> WeatherResponse {
    let url = buildURL(
      latitude: latitude,
      longitude: longitude,
      models: models,
      windSpeedUnit: windSpeedUnit
    )

    let (data, response) = try await session.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          200...299 ~= httpResponse.statusCode else {
      throw OpenMeteoError.invalidResponse
    }

    do {
      return try JSONDecoder().decode(WeatherResponse.self, from: data)
    } catch {
      throw OpenMeteoError.decodingError(error)
    }
  }

  private func buildURL(
    latitude: Double,
    longitude: Double,
    models: [WeatherModel],
    windSpeedUnit: WindSpeedUnit
  ) -> URL {
    var components = URLComponents(string: "\(baseURL)/forecast")!

    let modelString = models.map(\.rawValue).joined(separator: ",")

    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
      URLQueryItem(name: "models", value: modelString),
      URLQueryItem(name: "wind_speed_unit", value: windSpeedUnit.rawValue)
    ]

    return components.url!
  }
}

public enum WeatherModel: String, CaseIterable {
  case ecmwfIfs025 = "ecmwf_ifs025"
  case iconSeamless = "icon_seamless"
}

public enum WindSpeedUnit: String, CaseIterable {
  case knots = "kn"
  case kmh = "kmh"
  case mph = "mph"
  case ms = "ms"
}

public enum OpenMeteoError: Error {
  case invalidURL
  case invalidResponse
  case decodingError(Error)
}

// MARK: - Response Models

public struct WeatherResponse: Decodable {
  public let latitude: Double
  public let longitude: Double
  public let generationTimeMs: Double
  public let utcOffsetSeconds: Int
  public let timezone: String
  public let timezoneAbbreviation: String
  public let elevation: Double
  public let hourly: [HourlyData]

  enum CodingKeys: String, CodingKey {
    case latitude, longitude, timezone, elevation
    case generationTimeMs = "generationtime_ms"
    case utcOffsetSeconds = "utc_offset_seconds"
    case timezoneAbbreviation = "timezone_abbreviation"
    case hourlyUnits = "hourly_units"
    case hourlyData = "hourly"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    latitude = try container.decode(Double.self, forKey: .latitude)
    longitude = try container.decode(Double.self, forKey: .longitude)
    generationTimeMs = try container.decode(Double.self, forKey: .generationTimeMs)
    utcOffsetSeconds = try container.decode(Int.self, forKey: .utcOffsetSeconds)
    timezone = try container.decode(String.self, forKey: .timezone)
    timezoneAbbreviation = try container.decode(String.self, forKey: .timezoneAbbreviation)
    elevation = try container.decode(Double.self, forKey: .elevation)

    let units = try container.decode(HourlyUnits.self, forKey: .hourlyUnits)
    let data = try container.decode(RawHourlyData.self, forKey: .hourlyData)

    // Transform raw data into structured hourly data
    hourly = Self.transformHourlyData(from: data, units: units)
  }

  private static func transformHourlyData(from data: RawHourlyData, units: HourlyUnits) -> [HourlyData] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TimeZone(abbreviation: "GMT")

    return data.time.enumerated().map { index, timeString in
      let date = formatter.date(from: timeString) ?? Date()

      var modelData: [WeatherModel: WeatherModelData] = [:]

      // ECMWF IFS025 data
      modelData[.ecmwfIfs025] = WeatherModelData(
        windSpeed: data.windSpeed10mEcmwfIfs025?[safe: index],
        windDirection: data.windDirection10mEcmwfIfs025?[safe: index],
        windGusts: data.windGusts10mEcmwfIfs025?[safe: index],
        windSpeedUnit: units.windSpeed10mEcmwfIfs025 ?? "kn",
        windDirectionUnit: units.windDirection10mEcmwfIfs025 ?? "°",
        windGustsUnit: units.windGusts10mEcmwfIfs025 ?? "kn"
      )

      // Icon Seamless data
      modelData[.iconSeamless] = WeatherModelData(
        windSpeed: data.windSpeed10mIconSeamless?[safe: index],
        windDirection: data.windDirection10mIconSeamless?[safe: index],
        windGusts: data.windGusts10mIconSeamless?[safe: index],
        windSpeedUnit: units.windSpeed10mIconSeamless ?? "kn",
        windDirectionUnit: units.windDirection10mIconSeamless ?? "°",
        windGustsUnit: units.windGusts10mIconSeamless ?? "kn"
      )

      return HourlyData(time: date, models: modelData)
    }
  }
}

private struct HourlyUnits: Decodable {
  let time: String
  let windSpeed10mEcmwfIfs025: String?
  let windDirection10mEcmwfIfs025: String?
  let windGusts10mEcmwfIfs025: String?
  let windSpeed10mIconSeamless: String?
  let windDirection10mIconSeamless: String?
  let windGusts10mIconSeamless: String?

  enum CodingKeys: String, CodingKey {
    case time
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"
  }
}

private struct RawHourlyData: Decodable {
  let time: [String]
  let windSpeed10mEcmwfIfs025: [Double]?
  let windDirection10mEcmwfIfs025: [Int]?
  let windGusts10mEcmwfIfs025: [Double]?
  let windSpeed10mIconSeamless: [Double]?
  let windDirection10mIconSeamless: [Int]?
  let windGusts10mIconSeamless: [Double]?

  enum CodingKeys: String, CodingKey {
    case time
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"
  }
}

public struct HourlyData {
  public let time: Date
  public let models: [WeatherModel: WeatherModelData]

  // Convenience accessors for each model
  public subscript(model: WeatherModel) -> WeatherModelData? {
    return models[model]
  }
}

public struct WeatherModelData {
  public let windSpeed: Double?
  public let windDirection: Int?
  public let windGusts: Double?
  public let windSpeedUnit: String
  public let windDirectionUnit: String
  public let windGustsUnit: String
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
