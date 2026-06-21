//
//  Client.swift
//  OpenMeteoKit
//
//  Created by Adrian Corscadden on 2025-06-18.
//

import Foundation

public struct OpenMeteoClient {
  private let baseURL: String
  private let apiKey: String?
  private let session = URLSession.shared

  public init(baseURL: String = "https://api.open-meteo.com/v1", apiKey: String? = nil) {
    self.baseURL = baseURL
    self.apiKey = apiKey
  }

  /// Appends the apiKey query item (if configured) to the given URL.
  /// Internal mirror of `applyingAPIKey` usable from extensions in other files.
  func applyingAPIKeyPublic(to url: URL) -> URL {
    applyingAPIKey(to: url)
  }

  /// Appends the apiKey query item (if configured) to the given URL.
  private func applyingAPIKey(to url: URL) -> URL {
    guard let apiKey, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }
    var items = components.queryItems ?? []
    items.append(URLQueryItem(name: "apikey", value: apiKey))
    components.queryItems = items
    return components.url ?? url
  }

  public func fetchFreezingLevel(
    latitude: Double,
    longitude: Double,
    forecastDays: Int = 10
  ) async throws -> FreezingLevelResponse {
    let url = applyingAPIKey(to: buildFreezingLevelURL(
      latitude: latitude,
      longitude: longitude,
      forecastDays: forecastDays
    ))

    let (data, response) = try await session.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          200...299 ~= httpResponse.statusCode else {
      throw OpenMeteoError.invalidResponse
    }

    do {
      let raw = try JSONDecoder().decode(RawFreezingLevelResponse.self, from: data)
      return Self.transformFreezingLevelResponse(from: raw)
    } catch {
      throw OpenMeteoError.decodingError(error)
    }
  }

  public func fetchWeatherData(
    latitude: Double,
    longitude: Double,
    models: [WeatherModel] = [.ecmwfIfs025, .iconSeamless],
    windSpeedUnit: WindSpeedUnit = .knots,
    dataTypes: WeatherDataType = .all,
    forecastDays: Int = 10,
    includeDaily: Bool = true
  ) async throws -> OpenMeteoWeatherResponse {
    let url = applyingAPIKey(to: buildURL(
      latitude: latitude,
      longitude: longitude,
      models: models,
      windSpeedUnit: windSpeedUnit,
      dataTypes: dataTypes,
      forecastDays: forecastDays,
      includeDaily: includeDaily
    ))

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
    dataTypes: WeatherDataType,
    forecastDays: Int,
    includeDaily: Bool
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
    if dataTypes.contains(.temperature) {
      hourlyParams.append(contentsOf: [
        "temperature_2m",
        "apparent_temperature",
        "dew_point_2m",
        "relative_humidity_2m",
        "pressure_msl",
        "is_day"
      ])
    }
    if dataTypes.contains(.freezingLevel) {
      hourlyParams.append("freezing_level_height")
    }
    if dataTypes.contains(.cloudCover) {
      hourlyParams.append("cloud_cover")
    }

    var queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "hourly", value: hourlyParams.joined(separator: ",")),
      URLQueryItem(name: "models", value: modelString),
      URLQueryItem(name: "wind_speed_unit", value: windSpeedUnit.rawValue),
      URLQueryItem(name: "forecast_days", value: String(forecastDays)),
      URLQueryItem(name: "timezone", value: "auto")
    ]

    if includeDaily {
      let dailyParams = [
        "temperature_2m_max",
        "temperature_2m_min",
        "sunrise",
        "sunset",
        "precipitation_sum",
        "snowfall_sum",
        "precipitation_probability_max",
        "wind_speed_10m_max",
        "wind_gusts_10m_max",
        "weather_code",
        "uv_index_max"
      ]
      queryItems.append(URLQueryItem(name: "daily", value: dailyParams.joined(separator: ",")))
    }

    components.queryItems = queryItems

    return components.url!
  }

  private func buildFreezingLevelURL(
    latitude: Double,
    longitude: Double,
    forecastDays: Int
  ) -> URL {
    var components = URLComponents(string: "\(baseURL)/forecast")!

    components.queryItems = [
      URLQueryItem(name: "latitude", value: String(latitude)),
      URLQueryItem(name: "longitude", value: String(longitude)),
      URLQueryItem(name: "hourly", value: "freezing_level_height"),
      URLQueryItem(name: "forecast_days", value: String(forecastDays)),
      URLQueryItem(name: "timezone", value: "auto")
    ]

    return components.url!
  }

  private static func transformFreezingLevelResponse(from raw: RawFreezingLevelResponse) -> FreezingLevelResponse {
    let locationTimezone = TimeZone(identifier: raw.timezone) ?? TimeZone(secondsFromGMT: 0)!
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = locationTimezone

    var dataPoints: [FreezingLevelDataPoint] = []
    for (index, timeString) in raw.hourly.time.enumerated() {
      guard index < raw.hourly.freezingLevelHeight.count,
            let height = raw.hourly.freezingLevelHeight[index],
            let date = formatter.date(from: timeString)
      else { continue }
      dataPoints.append(FreezingLevelDataPoint(date: date, heightMeters: height))
    }

    return FreezingLevelResponse(timezone: raw.timezone, hourly: dataPoints)
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

  /// Returns whether this model provides coverage for the given coordinates.
  /// Based on known model domain boundaries.
  /// - Parameters:
  ///   - latitude: Latitude in degrees (-90 to 90)
  ///   - longitude: Longitude in degrees (-180 to 180)
  /// - Returns: true if the model covers this location
  public func isAvailable(latitude: Double, longitude: Double) -> Bool {
    switch self {
    // Global models - available everywhere
    case .ecmwfIfs025, .ecmwfAifs025, .iconSeamless, .gfsSeamless, .gemGlobal:
      return true

    // HRRR - CONUS domain
    // Source: https://rapidrefresh.noaa.gov/hrrr/HRRR_conus.domain.txt
    // Approximate bounding box: 21.14°N-47.84°N, 134.10°W-60.90°W
    case .hrrr:
      return latitude >= 21.0 && latitude <= 48.0 &&
             longitude >= -135.0 && longitude <= -60.0

    // NBM - CONUS domain (slightly larger than HRRR, includes parts of Canada/Mexico)
    // Source: https://vlab.noaa.gov/web/mdl/nbm
    case .nbm:
      return latitude >= 20.0 && latitude <= 50.0 &&
             longitude >= -135.0 && longitude <= -60.0

    // GEM Regional (RDPS) - North America
    // Source: https://wiki.usask.ca/pages/viewpage.action?pageId=1466958353
    case .gemRegional:
      return latitude >= 10.0 && latitude <= 75.0 &&
             longitude >= -175.0 && longitude <= -40.0

    // GEM HRDPS Continental - Canada and northern US
    // Source: https://eccc-msc.github.io/open-data/msc-data/nwp_hrdps/readme_hrdps-datamart_en/
    case .gemHrdpsContinental:
      return latitude >= 38.0 && latitude <= 70.0 &&
             longitude >= -143.0 && longitude <= -50.0
    }
  }

  /// Returns all models that provide coverage for the given coordinates.
  /// - Parameters:
  ///   - latitude: Latitude in degrees (-90 to 90)
  ///   - longitude: Longitude in degrees (-180 to 180)
  /// - Returns: Array of available WeatherModel cases
  public static func availableModels(latitude: Double, longitude: Double) -> [WeatherModel] {
    return WeatherModel.allCases.filter { $0.isAvailable(latitude: latitude, longitude: longitude) }
  }

  // MARK: - Capabilities

  /// Maximum number of forecast days this model provides.
  public var maxForecastDays: Int {
    switch self {
    case .ecmwfIfs025: return 15
    case .ecmwfAifs025: return 15
    case .iconSeamless: return 7
    case .gfsSeamless: return 16
    case .hrrr: return 2
    case .nbm: return 11
    case .gemGlobal: return 10
    case .gemRegional: return 3
    case .gemHrdpsContinental: return 2
    }
  }

  /// Whether this model can stand alone for a 10-day forecast.
  /// Short-range / high-resolution models cannot and must be stitched onto a longer-range tail.
  public var standaloneTenDayCapable: Bool {
    switch self {
    case .hrrr, .gemHrdpsContinental, .gemRegional:
      return false
    default:
      return true
    }
  }

  /// Whether this is a short-range / high-resolution model.
  public var isHighResolution: Bool {
    switch self {
    case .hrrr, .gemHrdpsContinental, .gemRegional, .nbm:
      return true
    default:
      return false
    }
  }

  /// For a short-horizon model, returns the longer-range model to stitch onto, picked from coverage.
  /// Returns nil for models that already provide a full forecast horizon.
  /// - Parameters:
  ///   - latitude: Latitude in degrees (-90 to 90)
  ///   - longitude: Longitude in degrees (-180 to 180)
  public func tailModel(latitude: Double, longitude: Double) -> WeatherModel? {
    switch self {
    case .gemHrdpsContinental:
      return WeatherModel.gemRegional.isAvailable(latitude: latitude, longitude: longitude)
        ? .gemRegional
        : .gemGlobal
    case .gemRegional:
      return .gemGlobal
    case .hrrr:
      return WeatherModel.nbm.isAvailable(latitude: latitude, longitude: longitude)
        ? .nbm
        : .gfsSeamless
    default:
      return nil
    }
  }
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
  public static let temperature = WeatherDataType(rawValue: 1 << 2)
  public static let freezingLevel = WeatherDataType(rawValue: 1 << 3)
  public static let cloudCover = WeatherDataType(rawValue: 1 << 4)

  public static let all: WeatherDataType = [.wind, .precipitation, .temperature, .freezingLevel, .cloudCover]
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
  public let daily: [DailyData]

  enum CodingKeys: String, CodingKey {
    case latitude, longitude, timezone, elevation
    case generationTimeMs = "generationtime_ms"
    case utcOffsetSeconds = "utc_offset_seconds"
    case timezoneAbbreviation = "timezone_abbreviation"
    case hourlyUnits = "hourly_units"
    case hourlyData = "hourly"
    case dailyUnits = "daily_units"
    case dailyData = "daily"
  }

  /// A `CodingKey` that accepts any string key, used to decode the variable
  /// per-model field set returned by Open-Meteo (e.g. `temperature_2m_gem_global`).
  private struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
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

    // --- Hourly block (dynamic) ---
    let hourlyValues = try Self.decodeDynamicHourly(container, forKey: .hourlyData)
    let hourlyUnits = try Self.decodeDynamicUnits(container, forKey: .hourlyUnits)
    hourly = Self.buildHourly(values: hourlyValues, units: hourlyUnits)

    // --- Daily block (dynamic, optional) ---
    if container.contains(.dailyData) {
      let dailyValues = try Self.decodeDynamicDaily(container, forKey: .dailyData)
      let dailyUnits = try Self.decodeDynamicUnits(container, forKey: .dailyUnits)
      daily = Self.buildDaily(values: dailyValues, units: dailyUnits)
    } else {
      daily = []
    }
  }

  /// Decodes a block keyed by full field names. `time` is `[String]`; all other
  /// keys decode to `[Double?]`.
  private static func decodeDynamicHourly(
    _ container: KeyedDecodingContainer<CodingKeys>,
    forKey key: CodingKeys
  ) throws -> (time: [String], fields: [String: [Double?]]) {
    let block = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: key)
    var time: [String] = []
    var fields: [String: [Double?]] = [:]
    for k in block.allKeys {
      if k.stringValue == "time" {
        time = try block.decode([String].self, forKey: k)
      } else {
        fields[k.stringValue] = try block.decode([Double?].self, forKey: k)
      }
    }
    return (time, fields)
  }

  /// Decodes the daily block. `time` and the date-like string fields (`sunrise_*`,
  /// `sunset_*`) decode to `[String?]`; everything else to `[Double?]`.
  private static func decodeDynamicDaily(
    _ container: KeyedDecodingContainer<CodingKeys>,
    forKey key: CodingKeys
  ) throws -> (time: [String], strings: [String: [String?]], fields: [String: [Double?]]) {
    let block = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: key)
    var time: [String] = []
    var strings: [String: [String?]] = [:]
    var fields: [String: [Double?]] = [:]
    for k in block.allKeys {
      let name = k.stringValue
      if name == "time" {
        time = try block.decode([String].self, forKey: k)
      } else if name.hasPrefix("sunrise") || name.hasPrefix("sunset") {
        strings[name] = try block.decode([String?].self, forKey: k)
      } else {
        fields[name] = try block.decode([Double?].self, forKey: k)
      }
    }
    return (time, strings, fields)
  }

  /// Decodes a `*_units` block into `[fieldName: unitString]`.
  private static func decodeDynamicUnits(
    _ container: KeyedDecodingContainer<CodingKeys>,
    forKey key: CodingKeys
  ) throws -> [String: String] {
    let block = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: key)
    var units: [String: String] = [:]
    for k in block.allKeys {
      units[k.stringValue] = try? block.decode(String.self, forKey: k)
    }
    return units
  }

  // MARK: Builders

  private static func buildHourly(
    values: (time: [String], fields: [String: [Double?]]),
    units: [String: String]
  ) -> [HourlyData] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TimeZone(abbreviation: "GMT")

    // Determine which models are present from the decoded field keys.
    let models = presentModels(in: Set(values.fields.keys))

    /// Looks up `<field>_<model>` at index `i`.
    func d(_ field: String, _ model: WeatherModel, at i: Int) -> Double? {
      guard let arr = values.fields["\(field)_\(model.rawValue)"], arr.indices.contains(i) else {
        return nil
      }
      return arr[i]
    }

    func u(_ field: String, _ model: WeatherModel) -> String? {
      units["\(field)_\(model.rawValue)"]
    }

    return values.time.enumerated().map { (index, timeString) in
      let date = formatter.date(from: timeString) ?? Date()
      var modelData: [WeatherModel: WeatherModelData] = [:]

      for model in models {
        modelData[model] = WeatherModelData(
          windSpeed: d("wind_speed_10m", model, at: index),
          windDirection: d("wind_direction_10m", model, at: index).map { Int($0) },
          windGusts: d("wind_gusts_10m", model, at: index),
          windSpeedUnit: u("wind_speed_10m", model),
          windDirectionUnit: u("wind_direction_10m", model),
          windGustsUnit: u("wind_gusts_10m", model),
          precipitation: d("precipitation", model, at: index),
          rain: d("rain", model, at: index),
          showers: d("showers", model, at: index),
          snowfall: d("snowfall", model, at: index),
          precipitationProbability: d("precipitation_probability", model, at: index).map { Int($0) },
          precipitationUnit: u("precipitation", model),
          rainUnit: u("rain", model),
          showersUnit: u("showers", model),
          snowfallUnit: u("snowfall", model),
          precipitationProbabilityUnit: u("precipitation_probability", model),
          weatherCode: d("weather_code", model, at: index).map { Int($0) },
          weatherCodeUnit: u("weather_code", model),
          temperature: d("temperature_2m", model, at: index),
          temperatureUnit: u("temperature_2m", model),
          apparentTemperature: d("apparent_temperature", model, at: index),
          apparentTemperatureUnit: u("apparent_temperature", model),
          dewPoint: d("dew_point_2m", model, at: index),
          dewPointUnit: u("dew_point_2m", model),
          relativeHumidity: d("relative_humidity_2m", model, at: index),
          relativeHumidityUnit: u("relative_humidity_2m", model),
          pressureMsl: d("pressure_msl", model, at: index),
          pressureMslUnit: u("pressure_msl", model),
          isDay: d("is_day", model, at: index).map { $0 != 0 },
          freezingLevelHeight: d("freezing_level_height", model, at: index),
          freezingLevelHeightUnit: u("freezing_level_height", model),
          cloudCover: d("cloud_cover", model, at: index).map { Int($0) },
          cloudCoverUnit: u("cloud_cover", model)
        )
      }

      return HourlyData(time: date, models: modelData)
    }
  }

  private static func buildDaily(
    values: (time: [String], strings: [String: [String?]], fields: [String: [Double?]]),
    units: [String: String]
  ) -> [DailyData] {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

    let dateTimeFormatter = DateFormatter()
    dateTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    dateTimeFormatter.timeZone = TimeZone(abbreviation: "GMT")

    let models = presentModels(in: Set(values.fields.keys).union(values.strings.keys))

    func d(_ field: String, _ model: WeatherModel, at i: Int) -> Double? {
      guard let arr = values.fields["\(field)_\(model.rawValue)"], arr.indices.contains(i) else {
        return nil
      }
      return arr[i]
    }

    func s(_ field: String, _ model: WeatherModel, at i: Int) -> Date? {
      guard let arr = values.strings["\(field)_\(model.rawValue)"],
            arr.indices.contains(i),
            let str = arr[i] else {
        return nil
      }
      return dateTimeFormatter.date(from: str)
    }

    return values.time.enumerated().map { (index, timeString) in
      let date = dateFormatter.date(from: timeString) ?? Date()
      var modelData: [WeatherModel: DailyModelData] = [:]

      for model in models {
        modelData[model] = DailyModelData(
          temperatureMax: d("temperature_2m_max", model, at: index),
          temperatureMin: d("temperature_2m_min", model, at: index),
          sunrise: s("sunrise", model, at: index),
          sunset: s("sunset", model, at: index),
          precipitationSum: d("precipitation_sum", model, at: index),
          snowfallSum: d("snowfall_sum", model, at: index),
          precipitationProbabilityMax: d("precipitation_probability_max", model, at: index).map { Int($0) },
          windSpeedMax: d("wind_speed_10m_max", model, at: index),
          windGustsMax: d("wind_gusts_10m_max", model, at: index),
          weatherCode: d("weather_code", model, at: index).map { Int($0) },
          uvIndexMax: d("uv_index_max", model, at: index)
        )
      }

      return DailyData(date: date, models: modelData)
    }
  }

  /// Determines which `WeatherModel` cases are present by matching the suffix of
  /// decoded field keys (e.g. a key ending in `_gem_global` implies `.gemGlobal`).
  private static func presentModels(in keys: Set<String>) -> Set<WeatherModel> {
    var result: Set<WeatherModel> = []
    for model in WeatherModel.allCases {
      let suffix = "_\(model.rawValue)"
      if keys.contains(where: { $0.hasSuffix(suffix) }) {
        result.insert(model)
      }
    }
    return result
  }
}

// MARK: - Hourly

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

  // Temperature data
  public let temperature: Double?
  public let temperatureUnit: String?

  // Additional thermodynamic fields
  public let apparentTemperature: Double?
  public let apparentTemperatureUnit: String?
  public let dewPoint: Double?
  public let dewPointUnit: String?
  public let relativeHumidity: Double?
  public let relativeHumidityUnit: String?
  public let pressureMsl: Double?
  public let pressureMslUnit: String?
  public let isDay: Bool?

  // Freezing level height (altitude of 0°C level; not provided by every model)
  public let freezingLevelHeight: Double?
  public let freezingLevelHeightUnit: String?

  // Cloud cover data (0-100%)
  public let cloudCover: Int?
  public let cloudCoverUnit: String?

  public init(
    windSpeed: Double? = nil,
    windDirection: Int? = nil,
    windGusts: Double? = nil,
    windSpeedUnit: String? = nil,
    windDirectionUnit: String? = nil,
    windGustsUnit: String? = nil,
    precipitation: Double? = nil,
    rain: Double? = nil,
    showers: Double? = nil,
    snowfall: Double? = nil,
    precipitationProbability: Int? = nil,
    precipitationUnit: String? = nil,
    rainUnit: String? = nil,
    showersUnit: String? = nil,
    snowfallUnit: String? = nil,
    precipitationProbabilityUnit: String? = nil,
    weatherCode: Int? = nil,
    weatherCodeUnit: String? = nil,
    temperature: Double? = nil,
    temperatureUnit: String? = nil,
    apparentTemperature: Double? = nil,
    apparentTemperatureUnit: String? = nil,
    dewPoint: Double? = nil,
    dewPointUnit: String? = nil,
    relativeHumidity: Double? = nil,
    relativeHumidityUnit: String? = nil,
    pressureMsl: Double? = nil,
    pressureMslUnit: String? = nil,
    isDay: Bool? = nil,
    freezingLevelHeight: Double? = nil,
    freezingLevelHeightUnit: String? = nil,
    cloudCover: Int? = nil,
    cloudCoverUnit: String? = nil
  ) {
    self.windSpeed = windSpeed
    self.windDirection = windDirection
    self.windGusts = windGusts
    self.windSpeedUnit = windSpeedUnit
    self.windDirectionUnit = windDirectionUnit
    self.windGustsUnit = windGustsUnit
    self.precipitation = precipitation
    self.rain = rain
    self.showers = showers
    self.snowfall = snowfall
    self.precipitationProbability = precipitationProbability
    self.precipitationUnit = precipitationUnit
    self.rainUnit = rainUnit
    self.showersUnit = showersUnit
    self.snowfallUnit = snowfallUnit
    self.precipitationProbabilityUnit = precipitationProbabilityUnit
    self.weatherCode = weatherCode
    self.weatherCodeUnit = weatherCodeUnit
    self.temperature = temperature
    self.temperatureUnit = temperatureUnit
    self.apparentTemperature = apparentTemperature
    self.apparentTemperatureUnit = apparentTemperatureUnit
    self.dewPoint = dewPoint
    self.dewPointUnit = dewPointUnit
    self.relativeHumidity = relativeHumidity
    self.relativeHumidityUnit = relativeHumidityUnit
    self.pressureMsl = pressureMsl
    self.pressureMslUnit = pressureMslUnit
    self.isDay = isDay
    self.freezingLevelHeight = freezingLevelHeight
    self.freezingLevelHeightUnit = freezingLevelHeightUnit
    self.cloudCover = cloudCover
    self.cloudCoverUnit = cloudCoverUnit
  }
}

// MARK: - Daily

public struct DailyData {
  public let date: Date
  public let models: [WeatherModel: DailyModelData]

  public subscript(model: WeatherModel) -> DailyModelData? {
    return models[model]
  }
}

public struct DailyModelData {
  public let temperatureMax: Double?
  public let temperatureMin: Double?
  public let sunrise: Date?
  public let sunset: Date?
  public let precipitationSum: Double?
  public let snowfallSum: Double?
  public let precipitationProbabilityMax: Int?
  public let windSpeedMax: Double?
  public let windGustsMax: Double?
  public let weatherCode: Int?
  public let uvIndexMax: Double?

  public init(
    temperatureMax: Double? = nil,
    temperatureMin: Double? = nil,
    sunrise: Date? = nil,
    sunset: Date? = nil,
    precipitationSum: Double? = nil,
    snowfallSum: Double? = nil,
    precipitationProbabilityMax: Int? = nil,
    windSpeedMax: Double? = nil,
    windGustsMax: Double? = nil,
    weatherCode: Int? = nil,
    uvIndexMax: Double? = nil
  ) {
    self.temperatureMax = temperatureMax
    self.temperatureMin = temperatureMin
    self.sunrise = sunrise
    self.sunset = sunset
    self.precipitationSum = precipitationSum
    self.snowfallSum = snowfallSum
    self.precipitationProbabilityMax = precipitationProbabilityMax
    self.windSpeedMax = windSpeedMax
    self.windGustsMax = windGustsMax
    self.weatherCode = weatherCode
    self.uvIndexMax = uvIndexMax
  }
}

// MARK: - Freezing Level Response

public struct FreezingLevelResponse: Sendable {
  public let timezone: String
  public let hourly: [FreezingLevelDataPoint]
}

public struct FreezingLevelDataPoint: Sendable {
  public let date: Date
  public let heightMeters: Double
}

private struct RawFreezingLevelResponse: Decodable {
  let timezone: String
  let hourly: HourlyData

  struct HourlyData: Decodable {
    let time: [String]
    let freezingLevelHeight: [Double?]

    enum CodingKeys: String, CodingKey {
      case time
      case freezingLevelHeight = "freezing_level_height"
    }
  }
}
