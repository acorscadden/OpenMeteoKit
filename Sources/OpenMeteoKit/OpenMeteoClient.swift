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
  ) async throws -> OpenMeteoWeatherResponse {
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
      return try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: data)
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
      URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,rain,showers,snowfall,precipitation_probability,weather_code"),
      URLQueryItem(name: "models", value: modelString),
      URLQueryItem(name: "wind_speed_unit", value: windSpeedUnit.rawValue)
    ]

    return components.url!
  }
}

public enum WeatherModel: String, CaseIterable {
  case ecmwfIfs025 = "ecmwf_ifs025"
  case iconSeamless = "icon_seamless"
  case gem_hrdps_continental = "gem_hrdps_continental"
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

public struct OpenMeteoWeatherResponse: Decodable {
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

    return data.time.enumerated().map { (index: Int, timeString: String) -> HourlyData in
      let date = formatter.date(from: timeString) ?? Date()

      var modelData: [WeatherModel: WeatherModelData] = [:]

      // ECMWF IFS025 data
      modelData[.ecmwfIfs025] = WeatherModelData(
        windSpeed: data.windSpeed10mEcmwfIfs025?[safe: index] ?? nil,
        windDirection: data.windDirection10mEcmwfIfs025?[safe: index] ?? nil,
        windGusts: data.windGusts10mEcmwfIfs025?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mEcmwfIfs025 ?? "kn",
        windDirectionUnit: units.windDirection10mEcmwfIfs025 ?? "°",
        windGustsUnit: units.windGusts10mEcmwfIfs025 ?? "kn",
        precipitation: data.precipitationEcmwfIfs025?[safe: index] ?? nil,
        rain: data.rainEcmwfIfs025?[safe: index] ?? nil,
        showers: data.showersEcmwfIfs025?[safe: index] ?? nil,
        snowfall: data.snowfallEcmwfIfs025?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityEcmwfIfs025?[safe: index] ?? nil,
        precipitationUnit: units.precipitationEcmwfIfs025 ?? "mm",
        rainUnit: units.rainEcmwfIfs025 ?? "mm",
        showersUnit: units.showersEcmwfIfs025 ?? "mm",
        snowfallUnit: units.snowfallEcmwfIfs025 ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityEcmwfIfs025 ?? "%",
        weatherCode: data.weatherCodeEcmwfIfs025?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeEcmwfIfs025 ?? "wmo code"
      )

      // Icon Seamless data
      modelData[.iconSeamless] = WeatherModelData(
        windSpeed: data.windSpeed10mIconSeamless?[safe: index] ?? nil,
        windDirection: data.windDirection10mIconSeamless?[safe: index] ?? nil,
        windGusts: data.windGusts10mIconSeamless?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mIconSeamless ?? "kn",
        windDirectionUnit: units.windDirection10mIconSeamless ?? "°",
        windGustsUnit: units.windGusts10mIconSeamless ?? "kn",
        precipitation: data.precipitationIconSeamless?[safe: index] ?? nil,
        rain: data.rainIconSeamless?[safe: index] ?? nil,
        showers: data.showersIconSeamless?[safe: index] ?? nil,
        snowfall: data.snowfallIconSeamless?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityIconSeamless?[safe: index] ?? nil,
        precipitationUnit: units.precipitationIconSeamless ?? "mm",
        rainUnit: units.rainIconSeamless ?? "mm",
        showersUnit: units.showersIconSeamless ?? "mm",
        snowfallUnit: units.snowfallIconSeamless ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityIconSeamless ?? "%",
        weatherCode: data.weatherCodeIconSeamless?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeIconSeamless ?? "wmo code"
      )

      // GEM HRDPS Continental data
      modelData[.gem_hrdps_continental] = WeatherModelData(
        windSpeed: data.windSpeed10mGemHrdpsContinental?[safe: index] ?? nil,
        windDirection: data.windDirection10mGemHrdpsContinental?[safe: index] ?? nil,
        windGusts: data.windGusts10mGemHrdpsContinental?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mGemHrdpsContinental ?? "kn",
        windDirectionUnit: units.windDirection10mGemHrdpsContinental ?? "°",
        windGustsUnit: units.windGusts10mGemHrdpsContinental ?? "kn",
        precipitation: data.precipitationGemHrdpsContinental?[safe: index] ?? nil,
        rain: data.rainGemHrdpsContinental?[safe: index] ?? nil,
        showers: data.showersGemHrdpsContinental?[safe: index] ?? nil,
        snowfall: data.snowfallGemHrdpsContinental?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityGemHrdpsContinental?[safe: index] ?? nil,
        precipitationUnit: units.precipitationGemHrdpsContinental ?? "mm",
        rainUnit: units.rainGemHrdpsContinental ?? "mm",
        showersUnit: units.showersGemHrdpsContinental ?? "mm",
        snowfallUnit: units.snowfallGemHrdpsContinental ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityGemHrdpsContinental ?? "%",
        weatherCode: data.weatherCodeGemHrdpsContinental?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeGemHrdpsContinental ?? "wmo code"
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
  let windSpeed10mGemHrdpsContinental: String?
  let windDirection10mGemHrdpsContinental: String?
  let windGusts10mGemHrdpsContinental: String?

  // Precipitation units - ECMWF
  let precipitationEcmwfIfs025: String?
  let rainEcmwfIfs025: String?
  let showersEcmwfIfs025: String?
  let snowfallEcmwfIfs025: String?
  let precipitationProbabilityEcmwfIfs025: String?

  // Precipitation units - Icon Seamless
  let precipitationIconSeamless: String?
  let rainIconSeamless: String?
  let showersIconSeamless: String?
  let snowfallIconSeamless: String?
  let precipitationProbabilityIconSeamless: String?

  // Precipitation units - GEM HRDPS
  let precipitationGemHrdpsContinental: String?
  let rainGemHrdpsContinental: String?
  let showersGemHrdpsContinental: String?
  let snowfallGemHrdpsContinental: String?
  let precipitationProbabilityGemHrdpsContinental: String?

  // Weather code units
  let weatherCodeEcmwfIfs025: String?
  let weatherCodeIconSeamless: String?
  let weatherCodeGemHrdpsContinental: String?

  enum CodingKeys: String, CodingKey {
    case time
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"
    case windSpeed10mGemHrdpsContinental = "wind_speed_10m_gem_hrdps_continental"
    case windDirection10mGemHrdpsContinental = "wind_direction_10m_gem_hrdps_continental"
    case windGusts10mGemHrdpsContinental = "wind_gusts_10m_gem_hrdps_continental"

    // Precipitation - ECMWF
    case precipitationEcmwfIfs025 = "precipitation_ecmwf_ifs025"
    case rainEcmwfIfs025 = "rain_ecmwf_ifs025"
    case showersEcmwfIfs025 = "showers_ecmwf_ifs025"
    case snowfallEcmwfIfs025 = "snowfall_ecmwf_ifs025"
    case precipitationProbabilityEcmwfIfs025 = "precipitation_probability_ecmwf_ifs025"

    // Precipitation - Icon Seamless
    case precipitationIconSeamless = "precipitation_icon_seamless"
    case rainIconSeamless = "rain_icon_seamless"
    case showersIconSeamless = "showers_icon_seamless"
    case snowfallIconSeamless = "snowfall_icon_seamless"
    case precipitationProbabilityIconSeamless = "precipitation_probability_icon_seamless"

    // Precipitation - GEM HRDPS
    case precipitationGemHrdpsContinental = "precipitation_gem_hrdps_continental"
    case rainGemHrdpsContinental = "rain_gem_hrdps_continental"
    case showersGemHrdpsContinental = "showers_gem_hrdps_continental"
    case snowfallGemHrdpsContinental = "snowfall_gem_hrdps_continental"
    case precipitationProbabilityGemHrdpsContinental = "precipitation_probability_gem_hrdps_continental"

    // Weather code
    case weatherCodeEcmwfIfs025 = "weather_code_ecmwf_ifs025"
    case weatherCodeIconSeamless = "weather_code_icon_seamless"
    case weatherCodeGemHrdpsContinental = "weather_code_gem_hrdps_continental"
  }
}

private struct RawHourlyData: Decodable {
  let time: [String]
  let windSpeed10mEcmwfIfs025: [Double?]?
  let windDirection10mEcmwfIfs025: [Int?]?
  let windGusts10mEcmwfIfs025: [Double?]?
  let windSpeed10mIconSeamless: [Double?]?
  let windDirection10mIconSeamless: [Int?]?
  let windGusts10mIconSeamless: [Double?]?
  let windSpeed10mGemHrdpsContinental: [Double?]?
  let windDirection10mGemHrdpsContinental: [Int?]?
  let windGusts10mGemHrdpsContinental: [Double?]?

  // Precipitation data - ECMWF
  let precipitationEcmwfIfs025: [Double?]?
  let rainEcmwfIfs025: [Double?]?
  let showersEcmwfIfs025: [Double?]?
  let snowfallEcmwfIfs025: [Double?]?
  let precipitationProbabilityEcmwfIfs025: [Int?]?

  // Precipitation data - Icon Seamless
  let precipitationIconSeamless: [Double?]?
  let rainIconSeamless: [Double?]?
  let showersIconSeamless: [Double?]?
  let snowfallIconSeamless: [Double?]?
  let precipitationProbabilityIconSeamless: [Int?]?

  // Precipitation data - GEM HRDPS
  let precipitationGemHrdpsContinental: [Double?]?
  let rainGemHrdpsContinental: [Double?]?
  let showersGemHrdpsContinental: [Double?]?
  let snowfallGemHrdpsContinental: [Double?]?
  let precipitationProbabilityGemHrdpsContinental: [Int?]?

  // Weather code data
  let weatherCodeEcmwfIfs025: [Int?]?
  let weatherCodeIconSeamless: [Int?]?
  let weatherCodeGemHrdpsContinental: [Int?]?

  enum CodingKeys: String, CodingKey {
    case time
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"
    case windSpeed10mGemHrdpsContinental = "wind_speed_10m_gem_hrdps_continental"
    case windDirection10mGemHrdpsContinental = "wind_direction_10m_gem_hrdps_continental"
    case windGusts10mGemHrdpsContinental = "wind_gusts_10m_gem_hrdps_continental"

    // Precipitation - ECMWF
    case precipitationEcmwfIfs025 = "precipitation_ecmwf_ifs025"
    case rainEcmwfIfs025 = "rain_ecmwf_ifs025"
    case showersEcmwfIfs025 = "showers_ecmwf_ifs025"
    case snowfallEcmwfIfs025 = "snowfall_ecmwf_ifs025"
    case precipitationProbabilityEcmwfIfs025 = "precipitation_probability_ecmwf_ifs025"

    // Precipitation - Icon Seamless
    case precipitationIconSeamless = "precipitation_icon_seamless"
    case rainIconSeamless = "rain_icon_seamless"
    case showersIconSeamless = "showers_icon_seamless"
    case snowfallIconSeamless = "snowfall_icon_seamless"
    case precipitationProbabilityIconSeamless = "precipitation_probability_icon_seamless"

    // Precipitation - GEM HRDPS
    case precipitationGemHrdpsContinental = "precipitation_gem_hrdps_continental"
    case rainGemHrdpsContinental = "rain_gem_hrdps_continental"
    case showersGemHrdpsContinental = "showers_gem_hrdps_continental"
    case snowfallGemHrdpsContinental = "snowfall_gem_hrdps_continental"
    case precipitationProbabilityGemHrdpsContinental = "precipitation_probability_gem_hrdps_continental"

    // Weather code
    case weatherCodeEcmwfIfs025 = "weather_code_ecmwf_ifs025"
    case weatherCodeIconSeamless = "weather_code_icon_seamless"
    case weatherCodeGemHrdpsContinental = "weather_code_gem_hrdps_continental"
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
  public let windSpeedUnit: String?
  public let windDirectionUnit: String?
  public let windGustsUnit: String?

  // Precipitation data
  public let precipitation: Double?
  public let rain: Double?
  public let showers: Double?
  public let snowfall: Double?
  public let precipitationProbability: Int?
  public let precipitationUnit: String?
  public let rainUnit: String?
  public let showersUnit: String?
  public let snowfallUnit: String?
  public let precipitationProbabilityUnit: String?

  // Weather condition
  public let weatherCode: Int?
  public let weatherCodeUnit: String?
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
