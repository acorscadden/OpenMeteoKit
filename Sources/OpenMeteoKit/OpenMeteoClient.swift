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

public struct WeatherResponse: Codable {
  public let latitude: Double
  public let longitude: Double
  public let generationTimeMs: Double
  public let utcOffsetSeconds: Int
  public let timezone: String
  public let timezoneAbbreviation: String
  public let elevation: Double
  public let hourlyUnits: HourlyUnits
  public let hourly: HourlyData

  enum CodingKeys: String, CodingKey {
    case latitude, longitude, timezone, elevation, hourly
    case generationTimeMs = "generationtime_ms"
    case utcOffsetSeconds = "utc_offset_seconds"
    case timezoneAbbreviation = "timezone_abbreviation"
    case hourlyUnits = "hourly_units"
  }
}

public struct HourlyUnits: Codable {
  public let time: String
  public let windSpeed10mEcmwfIfs025: String?
  public let windDirection10mEcmwfIfs025: String?
  public let windGusts10mEcmwfIfs025: String?
  public let windSpeed10mIconSeamless: String?
  public let windDirection10mIconSeamless: String?
  public let windGusts10mIconSeamless: String?

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

public struct HourlyData: Codable {
  public let time: [String]
  public let windSpeed10mEcmwfIfs025: [Double]?
  public let windDirection10mEcmwfIfs025: [Int]?
  public let windGusts10mEcmwfIfs025: [Double]?
  public let windSpeed10mIconSeamless: [Double]?
  public let windDirection10mIconSeamless: [Int]?
  public let windGusts10mIconSeamless: [Double]?

  enum CodingKeys: String, CodingKey {
    case time
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"
  }

  public var weatherDataPoints: [WeatherDataPoint] {
    var points: [WeatherDataPoint] = []

    for (index, timeString) in time.enumerated() {
      let ecmwfData = WeatherModelData(
        windSpeed: windSpeed10mEcmwfIfs025?[safe: index],
        windDirection: windDirection10mEcmwfIfs025?[safe: index],
        windGusts: windGusts10mEcmwfIfs025?[safe: index]
      )

      let iconData = WeatherModelData(
        windSpeed: windSpeed10mIconSeamless?[safe: index],
        windDirection: windDirection10mIconSeamless?[safe: index],
        windGusts: windGusts10mIconSeamless?[safe: index]
      )

      let point = WeatherDataPoint(
        time: timeString,
        ecmwfIfs025: ecmwfData,
        iconSeamless: iconData
      )

      points.append(point)
    }

    return points
  }
}

public struct WeatherDataPoint {
  public let time: String
  public let ecmwfIfs025: WeatherModelData
  public let iconSeamless: WeatherModelData

  public var date: Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    return formatter.date(from: time)
  }
}

public struct WeatherModelData {
  public let windSpeed: Double?
  public let windDirection: Int?
  public let windGusts: Double?
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
