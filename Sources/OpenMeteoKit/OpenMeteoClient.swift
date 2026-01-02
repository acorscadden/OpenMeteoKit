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
    windSpeedUnit: WindSpeedUnit = .knots,
    dataTypes: WeatherDataType = .all
  ) async throws -> OpenMeteoWeatherResponse {
    let url = buildURL(
      latitude: latitude,
      longitude: longitude,
      models: models,
      windSpeedUnit: windSpeedUnit,
      dataTypes: dataTypes
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
    windSpeedUnit: WindSpeedUnit,
    dataTypes: WeatherDataType
  ) -> URL {
    var components = URLComponents(string: "\(baseURL)/forecast")!

    let modelString = models.map(\.rawValue).joined(separator: ",")

    var hourlyParams: [String] = []
    if dataTypes.contains(.wind) {
      hourlyParams.append(contentsOf: ["wind_speed_10m", "wind_direction_10m", "wind_gusts_10m"])
    }
    if dataTypes.contains(.precipitation) {
      hourlyParams.append(contentsOf: ["precipitation", "rain", "showers", "snowfall", "precipitation_probability", "weather_code"])
    }

    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "hourly", value: hourlyParams.joined(separator: ",")),
      URLQueryItem(name: "models", value: modelString),
      URLQueryItem(name: "wind_speed_unit", value: windSpeedUnit.rawValue)
    ]

    return components.url!
  }
}

public enum WeatherModel: String, CaseIterable {
  // European models
  case ecmwfIfs025 = "ecmwf_ifs025"
  case ecmwfAifs025 = "ecmwf_aifs025"

  // German models
  case iconSeamless = "icon_seamless"

  // American models
  case gfsSeamless = "gfs_seamless"
  case hrrr = "ncep_hrrr_conus"
  case nbm = "ncep_nbm_conus"

  // Canadian models
  case gemGlobal = "gem_global"
  case gemRegional = "gem_regional"
  case gemHrdpsContinental = "gem_hrdps_continental"

  // Ensemble models (requires different API endpoint - not yet supported)
  // case gfsEnsemble = "gfs_ensemble_seamless"
}

public enum WindSpeedUnit: String, CaseIterable {
  case knots = "kn"
  case kmh = "kmh"
  case mph = "mph"
  case ms = "ms"
}

public struct WeatherDataType: OptionSet, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let wind = WeatherDataType(rawValue: 1 << 0)
  public static let precipitation = WeatherDataType(rawValue: 1 << 1)

  public static let all: WeatherDataType = [.wind, .precipitation]
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
      modelData[.gemHrdpsContinental] = WeatherModelData(
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

      // ECMWF AIFS data
      modelData[.ecmwfAifs025] = WeatherModelData(
        windSpeed: data.windSpeed10mEcmwfAifs025?[safe: index] ?? nil,
        windDirection: data.windDirection10mEcmwfAifs025?[safe: index] ?? nil,
        windGusts: data.windGusts10mEcmwfAifs025?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mEcmwfAifs025 ?? "kn",
        windDirectionUnit: units.windDirection10mEcmwfAifs025 ?? "°",
        windGustsUnit: units.windGusts10mEcmwfAifs025 ?? "kn",
        precipitation: data.precipitationEcmwfAifs025?[safe: index] ?? nil,
        rain: data.rainEcmwfAifs025?[safe: index] ?? nil,
        showers: data.showersEcmwfAifs025?[safe: index] ?? nil,
        snowfall: data.snowfallEcmwfAifs025?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityEcmwfAifs025?[safe: index] ?? nil,
        precipitationUnit: units.precipitationEcmwfAifs025 ?? "mm",
        rainUnit: units.rainEcmwfAifs025 ?? "mm",
        showersUnit: units.showersEcmwfAifs025 ?? "mm",
        snowfallUnit: units.snowfallEcmwfAifs025 ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityEcmwfAifs025 ?? "%",
        weatherCode: data.weatherCodeEcmwfAifs025?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeEcmwfAifs025 ?? "wmo code"
      )

      // GFS Seamless data
      modelData[.gfsSeamless] = WeatherModelData(
        windSpeed: data.windSpeed10mGfsSeamless?[safe: index] ?? nil,
        windDirection: data.windDirection10mGfsSeamless?[safe: index] ?? nil,
        windGusts: data.windGusts10mGfsSeamless?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mGfsSeamless ?? "kn",
        windDirectionUnit: units.windDirection10mGfsSeamless ?? "°",
        windGustsUnit: units.windGusts10mGfsSeamless ?? "kn",
        precipitation: data.precipitationGfsSeamless?[safe: index] ?? nil,
        rain: data.rainGfsSeamless?[safe: index] ?? nil,
        showers: data.showersGfsSeamless?[safe: index] ?? nil,
        snowfall: data.snowfallGfsSeamless?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityGfsSeamless?[safe: index] ?? nil,
        precipitationUnit: units.precipitationGfsSeamless ?? "mm",
        rainUnit: units.rainGfsSeamless ?? "mm",
        showersUnit: units.showersGfsSeamless ?? "mm",
        snowfallUnit: units.snowfallGfsSeamless ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityGfsSeamless ?? "%",
        weatherCode: data.weatherCodeGfsSeamless?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeGfsSeamless ?? "wmo code"
      )

      // HRRR data
      modelData[.hrrr] = WeatherModelData(
        windSpeed: data.windSpeed10mHrrrConus?[safe: index] ?? nil,
        windDirection: data.windDirection10mHrrrConus?[safe: index] ?? nil,
        windGusts: data.windGusts10mHrrrConus?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mHrrrConus ?? "kn",
        windDirectionUnit: units.windDirection10mHrrrConus ?? "°",
        windGustsUnit: units.windGusts10mHrrrConus ?? "kn",
        precipitation: data.precipitationHrrrConus?[safe: index] ?? nil,
        rain: data.rainHrrrConus?[safe: index] ?? nil,
        showers: data.showersHrrrConus?[safe: index] ?? nil,
        snowfall: data.snowfallHrrrConus?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityHrrrConus?[safe: index] ?? nil,
        precipitationUnit: units.precipitationHrrrConus ?? "mm",
        rainUnit: units.rainHrrrConus ?? "mm",
        showersUnit: units.showersHrrrConus ?? "mm",
        snowfallUnit: units.snowfallHrrrConus ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityHrrrConus ?? "%",
        weatherCode: data.weatherCodeHrrrConus?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeHrrrConus ?? "wmo code"
      )

      // NBM data
      modelData[.nbm] = WeatherModelData(
        windSpeed: data.windSpeed10mNbmConus?[safe: index] ?? nil,
        windDirection: data.windDirection10mNbmConus?[safe: index] ?? nil,
        windGusts: data.windGusts10mNbmConus?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mNbmConus ?? "kn",
        windDirectionUnit: units.windDirection10mNbmConus ?? "°",
        windGustsUnit: units.windGusts10mNbmConus ?? "kn",
        precipitation: data.precipitationNbmConus?[safe: index] ?? nil,
        rain: data.rainNbmConus?[safe: index] ?? nil,
        showers: data.showersNbmConus?[safe: index] ?? nil,
        snowfall: data.snowfallNbmConus?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityNbmConus?[safe: index] ?? nil,
        precipitationUnit: units.precipitationNbmConus ?? "mm",
        rainUnit: units.rainNbmConus ?? "mm",
        showersUnit: units.showersNbmConus ?? "mm",
        snowfallUnit: units.snowfallNbmConus ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityNbmConus ?? "%",
        weatherCode: data.weatherCodeNbmConus?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeNbmConus ?? "wmo code"
      )

      // GEM Global data
      modelData[.gemGlobal] = WeatherModelData(
        windSpeed: data.windSpeed10mGemGlobal?[safe: index] ?? nil,
        windDirection: data.windDirection10mGemGlobal?[safe: index] ?? nil,
        windGusts: data.windGusts10mGemGlobal?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mGemGlobal ?? "kn",
        windDirectionUnit: units.windDirection10mGemGlobal ?? "°",
        windGustsUnit: units.windGusts10mGemGlobal ?? "kn",
        precipitation: data.precipitationGemGlobal?[safe: index] ?? nil,
        rain: data.rainGemGlobal?[safe: index] ?? nil,
        showers: data.showersGemGlobal?[safe: index] ?? nil,
        snowfall: data.snowfallGemGlobal?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityGemGlobal?[safe: index] ?? nil,
        precipitationUnit: units.precipitationGemGlobal ?? "mm",
        rainUnit: units.rainGemGlobal ?? "mm",
        showersUnit: units.showersGemGlobal ?? "mm",
        snowfallUnit: units.snowfallGemGlobal ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityGemGlobal ?? "%",
        weatherCode: data.weatherCodeGemGlobal?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeGemGlobal ?? "wmo code"
      )

      // GEM Regional data
      modelData[.gemRegional] = WeatherModelData(
        windSpeed: data.windSpeed10mGemRegional?[safe: index] ?? nil,
        windDirection: data.windDirection10mGemRegional?[safe: index] ?? nil,
        windGusts: data.windGusts10mGemRegional?[safe: index] ?? nil,
        windSpeedUnit: units.windSpeed10mGemRegional ?? "kn",
        windDirectionUnit: units.windDirection10mGemRegional ?? "°",
        windGustsUnit: units.windGusts10mGemRegional ?? "kn",
        precipitation: data.precipitationGemRegional?[safe: index] ?? nil,
        rain: data.rainGemRegional?[safe: index] ?? nil,
        showers: data.showersGemRegional?[safe: index] ?? nil,
        snowfall: data.snowfallGemRegional?[safe: index] ?? nil,
        precipitationProbability: data.precipitationProbabilityGemRegional?[safe: index] ?? nil,
        precipitationUnit: units.precipitationGemRegional ?? "mm",
        rainUnit: units.rainGemRegional ?? "mm",
        showersUnit: units.showersGemRegional ?? "mm",
        snowfallUnit: units.snowfallGemRegional ?? "cm",
        precipitationProbabilityUnit: units.precipitationProbabilityGemRegional ?? "%",
        weatherCode: data.weatherCodeGemRegional?[safe: index] ?? nil,
        weatherCodeUnit: units.weatherCodeGemRegional ?? "wmo code"
      )

      return HourlyData(time: date, models: modelData)
    }
  }
}

private struct HourlyUnits: Decodable {
  let time: String

  // Wind units - ECMWF IFS
  let windSpeed10mEcmwfIfs025: String?
  let windDirection10mEcmwfIfs025: String?
  let windGusts10mEcmwfIfs025: String?

  // Wind units - ECMWF AIFS
  let windSpeed10mEcmwfAifs025: String?
  let windDirection10mEcmwfAifs025: String?
  let windGusts10mEcmwfAifs025: String?

  // Wind units - Icon Seamless
  let windSpeed10mIconSeamless: String?
  let windDirection10mIconSeamless: String?
  let windGusts10mIconSeamless: String?

  // Wind units - GFS Seamless
  let windSpeed10mGfsSeamless: String?
  let windDirection10mGfsSeamless: String?
  let windGusts10mGfsSeamless: String?

  // Wind units - HRRR
  let windSpeed10mHrrrConus: String?
  let windDirection10mHrrrConus: String?
  let windGusts10mHrrrConus: String?

  // Wind units - NBM
  let windSpeed10mNbmConus: String?
  let windDirection10mNbmConus: String?
  let windGusts10mNbmConus: String?

  // Wind units - GEM Global
  let windSpeed10mGemGlobal: String?
  let windDirection10mGemGlobal: String?
  let windGusts10mGemGlobal: String?

  // Wind units - GEM Regional
  let windSpeed10mGemRegional: String?
  let windDirection10mGemRegional: String?
  let windGusts10mGemRegional: String?

  // Wind units - GEM HRDPS Continental
  let windSpeed10mGemHrdpsContinental: String?
  let windDirection10mGemHrdpsContinental: String?
  let windGusts10mGemHrdpsContinental: String?

  // Precipitation units - ECMWF IFS
  let precipitationEcmwfIfs025: String?
  let rainEcmwfIfs025: String?
  let showersEcmwfIfs025: String?
  let snowfallEcmwfIfs025: String?
  let precipitationProbabilityEcmwfIfs025: String?

  // Precipitation units - ECMWF AIFS
  let precipitationEcmwfAifs025: String?
  let rainEcmwfAifs025: String?
  let showersEcmwfAifs025: String?
  let snowfallEcmwfAifs025: String?
  let precipitationProbabilityEcmwfAifs025: String?

  // Precipitation units - Icon Seamless
  let precipitationIconSeamless: String?
  let rainIconSeamless: String?
  let showersIconSeamless: String?
  let snowfallIconSeamless: String?
  let precipitationProbabilityIconSeamless: String?

  // Precipitation units - GFS Seamless
  let precipitationGfsSeamless: String?
  let rainGfsSeamless: String?
  let showersGfsSeamless: String?
  let snowfallGfsSeamless: String?
  let precipitationProbabilityGfsSeamless: String?

  // Precipitation units - HRRR
  let precipitationHrrrConus: String?
  let rainHrrrConus: String?
  let showersHrrrConus: String?
  let snowfallHrrrConus: String?
  let precipitationProbabilityHrrrConus: String?

  // Precipitation units - NBM
  let precipitationNbmConus: String?
  let rainNbmConus: String?
  let showersNbmConus: String?
  let snowfallNbmConus: String?
  let precipitationProbabilityNbmConus: String?

  // Precipitation units - GEM Global
  let precipitationGemGlobal: String?
  let rainGemGlobal: String?
  let showersGemGlobal: String?
  let snowfallGemGlobal: String?
  let precipitationProbabilityGemGlobal: String?

  // Precipitation units - GEM Regional
  let precipitationGemRegional: String?
  let rainGemRegional: String?
  let showersGemRegional: String?
  let snowfallGemRegional: String?
  let precipitationProbabilityGemRegional: String?

  // Precipitation units - GEM HRDPS Continental
  let precipitationGemHrdpsContinental: String?
  let rainGemHrdpsContinental: String?
  let showersGemHrdpsContinental: String?
  let snowfallGemHrdpsContinental: String?
  let precipitationProbabilityGemHrdpsContinental: String?

  // Weather code units
  let weatherCodeEcmwfIfs025: String?
  let weatherCodeEcmwfAifs025: String?
  let weatherCodeIconSeamless: String?
  let weatherCodeGfsSeamless: String?
  let weatherCodeHrrrConus: String?
  let weatherCodeNbmConus: String?
  let weatherCodeGemGlobal: String?
  let weatherCodeGemRegional: String?
  let weatherCodeGemHrdpsContinental: String?

  enum CodingKeys: String, CodingKey {
    case time

    // Wind - ECMWF IFS
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"

    // Wind - ECMWF AIFS
    case windSpeed10mEcmwfAifs025 = "wind_speed_10m_ecmwf_aifs025"
    case windDirection10mEcmwfAifs025 = "wind_direction_10m_ecmwf_aifs025"
    case windGusts10mEcmwfAifs025 = "wind_gusts_10m_ecmwf_aifs025"

    // Wind - Icon Seamless
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"

    // Wind - GFS Seamless
    case windSpeed10mGfsSeamless = "wind_speed_10m_gfs_seamless"
    case windDirection10mGfsSeamless = "wind_direction_10m_gfs_seamless"
    case windGusts10mGfsSeamless = "wind_gusts_10m_gfs_seamless"

    // Wind - HRRR
    case windSpeed10mHrrrConus = "wind_speed_10m_ncep_hrrr_conus"
    case windDirection10mHrrrConus = "wind_direction_10m_ncep_hrrr_conus"
    case windGusts10mHrrrConus = "wind_gusts_10m_ncep_hrrr_conus"

    // Wind - NBM
    case windSpeed10mNbmConus = "wind_speed_10m_ncep_nbm_conus"
    case windDirection10mNbmConus = "wind_direction_10m_ncep_nbm_conus"
    case windGusts10mNbmConus = "wind_gusts_10m_ncep_nbm_conus"

    // Wind - GEM Global
    case windSpeed10mGemGlobal = "wind_speed_10m_gem_global"
    case windDirection10mGemGlobal = "wind_direction_10m_gem_global"
    case windGusts10mGemGlobal = "wind_gusts_10m_gem_global"

    // Wind - GEM Regional
    case windSpeed10mGemRegional = "wind_speed_10m_gem_regional"
    case windDirection10mGemRegional = "wind_direction_10m_gem_regional"
    case windGusts10mGemRegional = "wind_gusts_10m_gem_regional"

    // Wind - GEM HRDPS Continental
    case windSpeed10mGemHrdpsContinental = "wind_speed_10m_gem_hrdps_continental"
    case windDirection10mGemHrdpsContinental = "wind_direction_10m_gem_hrdps_continental"
    case windGusts10mGemHrdpsContinental = "wind_gusts_10m_gem_hrdps_continental"

    // Precipitation - ECMWF IFS
    case precipitationEcmwfIfs025 = "precipitation_ecmwf_ifs025"
    case rainEcmwfIfs025 = "rain_ecmwf_ifs025"
    case showersEcmwfIfs025 = "showers_ecmwf_ifs025"
    case snowfallEcmwfIfs025 = "snowfall_ecmwf_ifs025"
    case precipitationProbabilityEcmwfIfs025 = "precipitation_probability_ecmwf_ifs025"

    // Precipitation - ECMWF AIFS
    case precipitationEcmwfAifs025 = "precipitation_ecmwf_aifs025"
    case rainEcmwfAifs025 = "rain_ecmwf_aifs025"
    case showersEcmwfAifs025 = "showers_ecmwf_aifs025"
    case snowfallEcmwfAifs025 = "snowfall_ecmwf_aifs025"
    case precipitationProbabilityEcmwfAifs025 = "precipitation_probability_ecmwf_aifs025"

    // Precipitation - Icon Seamless
    case precipitationIconSeamless = "precipitation_icon_seamless"
    case rainIconSeamless = "rain_icon_seamless"
    case showersIconSeamless = "showers_icon_seamless"
    case snowfallIconSeamless = "snowfall_icon_seamless"
    case precipitationProbabilityIconSeamless = "precipitation_probability_icon_seamless"

    // Precipitation - GFS Seamless
    case precipitationGfsSeamless = "precipitation_gfs_seamless"
    case rainGfsSeamless = "rain_gfs_seamless"
    case showersGfsSeamless = "showers_gfs_seamless"
    case snowfallGfsSeamless = "snowfall_gfs_seamless"
    case precipitationProbabilityGfsSeamless = "precipitation_probability_gfs_seamless"

    // Precipitation - HRRR
    case precipitationHrrrConus = "precipitation_ncep_hrrr_conus"
    case rainHrrrConus = "rain_ncep_hrrr_conus"
    case showersHrrrConus = "showers_ncep_hrrr_conus"
    case snowfallHrrrConus = "snowfall_ncep_hrrr_conus"
    case precipitationProbabilityHrrrConus = "precipitation_probability_ncep_hrrr_conus"

    // Precipitation - NBM
    case precipitationNbmConus = "precipitation_ncep_nbm_conus"
    case rainNbmConus = "rain_ncep_nbm_conus"
    case showersNbmConus = "showers_ncep_nbm_conus"
    case snowfallNbmConus = "snowfall_ncep_nbm_conus"
    case precipitationProbabilityNbmConus = "precipitation_probability_ncep_nbm_conus"

    // Precipitation - GEM Global
    case precipitationGemGlobal = "precipitation_gem_global"
    case rainGemGlobal = "rain_gem_global"
    case showersGemGlobal = "showers_gem_global"
    case snowfallGemGlobal = "snowfall_gem_global"
    case precipitationProbabilityGemGlobal = "precipitation_probability_gem_global"

    // Precipitation - GEM Regional
    case precipitationGemRegional = "precipitation_gem_regional"
    case rainGemRegional = "rain_gem_regional"
    case showersGemRegional = "showers_gem_regional"
    case snowfallGemRegional = "snowfall_gem_regional"
    case precipitationProbabilityGemRegional = "precipitation_probability_gem_regional"

    // Precipitation - GEM HRDPS Continental
    case precipitationGemHrdpsContinental = "precipitation_gem_hrdps_continental"
    case rainGemHrdpsContinental = "rain_gem_hrdps_continental"
    case showersGemHrdpsContinental = "showers_gem_hrdps_continental"
    case snowfallGemHrdpsContinental = "snowfall_gem_hrdps_continental"
    case precipitationProbabilityGemHrdpsContinental = "precipitation_probability_gem_hrdps_continental"

    // Weather code
    case weatherCodeEcmwfIfs025 = "weather_code_ecmwf_ifs025"
    case weatherCodeEcmwfAifs025 = "weather_code_ecmwf_aifs025"
    case weatherCodeIconSeamless = "weather_code_icon_seamless"
    case weatherCodeGfsSeamless = "weather_code_gfs_seamless"
    case weatherCodeHrrrConus = "weather_code_ncep_hrrr_conus"
    case weatherCodeNbmConus = "weather_code_ncep_nbm_conus"
    case weatherCodeGemGlobal = "weather_code_gem_global"
    case weatherCodeGemRegional = "weather_code_gem_regional"
    case weatherCodeGemHrdpsContinental = "weather_code_gem_hrdps_continental"
  }
}

private struct RawHourlyData: Decodable {
  let time: [String]

  // Wind data - ECMWF IFS
  let windSpeed10mEcmwfIfs025: [Double?]?
  let windDirection10mEcmwfIfs025: [Int?]?
  let windGusts10mEcmwfIfs025: [Double?]?

  // Wind data - ECMWF AIFS
  let windSpeed10mEcmwfAifs025: [Double?]?
  let windDirection10mEcmwfAifs025: [Int?]?
  let windGusts10mEcmwfAifs025: [Double?]?

  // Wind data - Icon Seamless
  let windSpeed10mIconSeamless: [Double?]?
  let windDirection10mIconSeamless: [Int?]?
  let windGusts10mIconSeamless: [Double?]?

  // Wind data - GFS Seamless
  let windSpeed10mGfsSeamless: [Double?]?
  let windDirection10mGfsSeamless: [Int?]?
  let windGusts10mGfsSeamless: [Double?]?

  // Wind data - HRRR
  let windSpeed10mHrrrConus: [Double?]?
  let windDirection10mHrrrConus: [Int?]?
  let windGusts10mHrrrConus: [Double?]?

  // Wind data - NBM
  let windSpeed10mNbmConus: [Double?]?
  let windDirection10mNbmConus: [Int?]?
  let windGusts10mNbmConus: [Double?]?

  // Wind data - GEM Global
  let windSpeed10mGemGlobal: [Double?]?
  let windDirection10mGemGlobal: [Int?]?
  let windGusts10mGemGlobal: [Double?]?

  // Wind data - GEM Regional
  let windSpeed10mGemRegional: [Double?]?
  let windDirection10mGemRegional: [Int?]?
  let windGusts10mGemRegional: [Double?]?

  // Wind data - GEM HRDPS Continental
  let windSpeed10mGemHrdpsContinental: [Double?]?
  let windDirection10mGemHrdpsContinental: [Int?]?
  let windGusts10mGemHrdpsContinental: [Double?]?

  // Precipitation data - ECMWF IFS
  let precipitationEcmwfIfs025: [Double?]?
  let rainEcmwfIfs025: [Double?]?
  let showersEcmwfIfs025: [Double?]?
  let snowfallEcmwfIfs025: [Double?]?
  let precipitationProbabilityEcmwfIfs025: [Int?]?

  // Precipitation data - ECMWF AIFS
  let precipitationEcmwfAifs025: [Double?]?
  let rainEcmwfAifs025: [Double?]?
  let showersEcmwfAifs025: [Double?]?
  let snowfallEcmwfAifs025: [Double?]?
  let precipitationProbabilityEcmwfAifs025: [Int?]?

  // Precipitation data - Icon Seamless
  let precipitationIconSeamless: [Double?]?
  let rainIconSeamless: [Double?]?
  let showersIconSeamless: [Double?]?
  let snowfallIconSeamless: [Double?]?
  let precipitationProbabilityIconSeamless: [Int?]?

  // Precipitation data - GFS Seamless
  let precipitationGfsSeamless: [Double?]?
  let rainGfsSeamless: [Double?]?
  let showersGfsSeamless: [Double?]?
  let snowfallGfsSeamless: [Double?]?
  let precipitationProbabilityGfsSeamless: [Int?]?

  // Precipitation data - HRRR
  let precipitationHrrrConus: [Double?]?
  let rainHrrrConus: [Double?]?
  let showersHrrrConus: [Double?]?
  let snowfallHrrrConus: [Double?]?
  let precipitationProbabilityHrrrConus: [Int?]?

  // Precipitation data - NBM
  let precipitationNbmConus: [Double?]?
  let rainNbmConus: [Double?]?
  let showersNbmConus: [Double?]?
  let snowfallNbmConus: [Double?]?
  let precipitationProbabilityNbmConus: [Int?]?

  // Precipitation data - GEM Global
  let precipitationGemGlobal: [Double?]?
  let rainGemGlobal: [Double?]?
  let showersGemGlobal: [Double?]?
  let snowfallGemGlobal: [Double?]?
  let precipitationProbabilityGemGlobal: [Int?]?

  // Precipitation data - GEM Regional
  let precipitationGemRegional: [Double?]?
  let rainGemRegional: [Double?]?
  let showersGemRegional: [Double?]?
  let snowfallGemRegional: [Double?]?
  let precipitationProbabilityGemRegional: [Int?]?

  // Precipitation data - GEM HRDPS Continental
  let precipitationGemHrdpsContinental: [Double?]?
  let rainGemHrdpsContinental: [Double?]?
  let showersGemHrdpsContinental: [Double?]?
  let snowfallGemHrdpsContinental: [Double?]?
  let precipitationProbabilityGemHrdpsContinental: [Int?]?

  // Weather code data
  let weatherCodeEcmwfIfs025: [Int?]?
  let weatherCodeEcmwfAifs025: [Int?]?
  let weatherCodeIconSeamless: [Int?]?
  let weatherCodeGfsSeamless: [Int?]?
  let weatherCodeHrrrConus: [Int?]?
  let weatherCodeNbmConus: [Int?]?
  let weatherCodeGemGlobal: [Int?]?
  let weatherCodeGemRegional: [Int?]?
  let weatherCodeGemHrdpsContinental: [Int?]?

  enum CodingKeys: String, CodingKey {
    case time

    // Wind - ECMWF IFS
    case windSpeed10mEcmwfIfs025 = "wind_speed_10m_ecmwf_ifs025"
    case windDirection10mEcmwfIfs025 = "wind_direction_10m_ecmwf_ifs025"
    case windGusts10mEcmwfIfs025 = "wind_gusts_10m_ecmwf_ifs025"

    // Wind - ECMWF AIFS
    case windSpeed10mEcmwfAifs025 = "wind_speed_10m_ecmwf_aifs025"
    case windDirection10mEcmwfAifs025 = "wind_direction_10m_ecmwf_aifs025"
    case windGusts10mEcmwfAifs025 = "wind_gusts_10m_ecmwf_aifs025"

    // Wind - Icon Seamless
    case windSpeed10mIconSeamless = "wind_speed_10m_icon_seamless"
    case windDirection10mIconSeamless = "wind_direction_10m_icon_seamless"
    case windGusts10mIconSeamless = "wind_gusts_10m_icon_seamless"

    // Wind - GFS Seamless
    case windSpeed10mGfsSeamless = "wind_speed_10m_gfs_seamless"
    case windDirection10mGfsSeamless = "wind_direction_10m_gfs_seamless"
    case windGusts10mGfsSeamless = "wind_gusts_10m_gfs_seamless"

    // Wind - HRRR
    case windSpeed10mHrrrConus = "wind_speed_10m_ncep_hrrr_conus"
    case windDirection10mHrrrConus = "wind_direction_10m_ncep_hrrr_conus"
    case windGusts10mHrrrConus = "wind_gusts_10m_ncep_hrrr_conus"

    // Wind - NBM
    case windSpeed10mNbmConus = "wind_speed_10m_ncep_nbm_conus"
    case windDirection10mNbmConus = "wind_direction_10m_ncep_nbm_conus"
    case windGusts10mNbmConus = "wind_gusts_10m_ncep_nbm_conus"

    // Wind - GEM Global
    case windSpeed10mGemGlobal = "wind_speed_10m_gem_global"
    case windDirection10mGemGlobal = "wind_direction_10m_gem_global"
    case windGusts10mGemGlobal = "wind_gusts_10m_gem_global"

    // Wind - GEM Regional
    case windSpeed10mGemRegional = "wind_speed_10m_gem_regional"
    case windDirection10mGemRegional = "wind_direction_10m_gem_regional"
    case windGusts10mGemRegional = "wind_gusts_10m_gem_regional"

    // Wind - GEM HRDPS Continental
    case windSpeed10mGemHrdpsContinental = "wind_speed_10m_gem_hrdps_continental"
    case windDirection10mGemHrdpsContinental = "wind_direction_10m_gem_hrdps_continental"
    case windGusts10mGemHrdpsContinental = "wind_gusts_10m_gem_hrdps_continental"

    // Precipitation - ECMWF IFS
    case precipitationEcmwfIfs025 = "precipitation_ecmwf_ifs025"
    case rainEcmwfIfs025 = "rain_ecmwf_ifs025"
    case showersEcmwfIfs025 = "showers_ecmwf_ifs025"
    case snowfallEcmwfIfs025 = "snowfall_ecmwf_ifs025"
    case precipitationProbabilityEcmwfIfs025 = "precipitation_probability_ecmwf_ifs025"

    // Precipitation - ECMWF AIFS
    case precipitationEcmwfAifs025 = "precipitation_ecmwf_aifs025"
    case rainEcmwfAifs025 = "rain_ecmwf_aifs025"
    case showersEcmwfAifs025 = "showers_ecmwf_aifs025"
    case snowfallEcmwfAifs025 = "snowfall_ecmwf_aifs025"
    case precipitationProbabilityEcmwfAifs025 = "precipitation_probability_ecmwf_aifs025"

    // Precipitation - Icon Seamless
    case precipitationIconSeamless = "precipitation_icon_seamless"
    case rainIconSeamless = "rain_icon_seamless"
    case showersIconSeamless = "showers_icon_seamless"
    case snowfallIconSeamless = "snowfall_icon_seamless"
    case precipitationProbabilityIconSeamless = "precipitation_probability_icon_seamless"

    // Precipitation - GFS Seamless
    case precipitationGfsSeamless = "precipitation_gfs_seamless"
    case rainGfsSeamless = "rain_gfs_seamless"
    case showersGfsSeamless = "showers_gfs_seamless"
    case snowfallGfsSeamless = "snowfall_gfs_seamless"
    case precipitationProbabilityGfsSeamless = "precipitation_probability_gfs_seamless"

    // Precipitation - HRRR
    case precipitationHrrrConus = "precipitation_ncep_hrrr_conus"
    case rainHrrrConus = "rain_ncep_hrrr_conus"
    case showersHrrrConus = "showers_ncep_hrrr_conus"
    case snowfallHrrrConus = "snowfall_ncep_hrrr_conus"
    case precipitationProbabilityHrrrConus = "precipitation_probability_ncep_hrrr_conus"

    // Precipitation - NBM
    case precipitationNbmConus = "precipitation_ncep_nbm_conus"
    case rainNbmConus = "rain_ncep_nbm_conus"
    case showersNbmConus = "showers_ncep_nbm_conus"
    case snowfallNbmConus = "snowfall_ncep_nbm_conus"
    case precipitationProbabilityNbmConus = "precipitation_probability_ncep_nbm_conus"

    // Precipitation - GEM Global
    case precipitationGemGlobal = "precipitation_gem_global"
    case rainGemGlobal = "rain_gem_global"
    case showersGemGlobal = "showers_gem_global"
    case snowfallGemGlobal = "snowfall_gem_global"
    case precipitationProbabilityGemGlobal = "precipitation_probability_gem_global"

    // Precipitation - GEM Regional
    case precipitationGemRegional = "precipitation_gem_regional"
    case rainGemRegional = "rain_gem_regional"
    case showersGemRegional = "showers_gem_regional"
    case snowfallGemRegional = "snowfall_gem_regional"
    case precipitationProbabilityGemRegional = "precipitation_probability_gem_regional"

    // Precipitation - GEM HRDPS Continental
    case precipitationGemHrdpsContinental = "precipitation_gem_hrdps_continental"
    case rainGemHrdpsContinental = "rain_gem_hrdps_continental"
    case showersGemHrdpsContinental = "showers_gem_hrdps_continental"
    case snowfallGemHrdpsContinental = "snowfall_gem_hrdps_continental"
    case precipitationProbabilityGemHrdpsContinental = "precipitation_probability_gem_hrdps_continental"

    // Weather code
    case weatherCodeEcmwfIfs025 = "weather_code_ecmwf_ifs025"
    case weatherCodeEcmwfAifs025 = "weather_code_ecmwf_aifs025"
    case weatherCodeIconSeamless = "weather_code_icon_seamless"
    case weatherCodeGfsSeamless = "weather_code_gfs_seamless"
    case weatherCodeHrrrConus = "weather_code_ncep_hrrr_conus"
    case weatherCodeNbmConus = "weather_code_ncep_nbm_conus"
    case weatherCodeGemGlobal = "weather_code_gem_global"
    case weatherCodeGemRegional = "weather_code_gem_regional"
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
