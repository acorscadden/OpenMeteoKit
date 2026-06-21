import Testing
import Foundation
@testable import OpenMeteoKit

// MARK: - Real-sample dynamic decode tests

private func loadSample() throws -> OpenMeteoWeatherResponse {
  let url = try #require(
    Bundle.module.url(forResource: "multi_model_sample", withExtension: "json"),
    "multi_model_sample.json must be bundled as a test resource"
  )
  let data = try Data(contentsOf: url)
  return try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: data)
}

@Test func testSampleHourlyTemperaturePresentForGemGlobal() throws {
  let response = try loadSample()
  #expect(!response.hourly.isEmpty)

  let first = response.hourly[0]
  let gem = first[.gemGlobal]
  #expect(gem != nil, "gem_global should be present")
  #expect(gem?.temperature != nil, "gem_global temperature should be non-nil")
  #expect(gem?.temperatureUnit == "°C")
}

@Test func testSampleHrdpsTemperatureNonNilEarlyNilTail() throws {
  let response = try loadSample()

  // Early in the forecast HRDPS has data.
  let early = response.hourly[0][.gemHrdpsContinental]
  #expect(early?.temperature != nil, "HRDPS temperature should be present early")

  // Far in the tail HRDPS is null-padded (short-range model).
  let tail = response.hourly[response.hourly.count - 1][.gemHrdpsContinental]
  #expect(tail?.temperature == nil, "HRDPS temperature should be nil in the far tail")

  // gem_global, being a 10-day model, still has data in the tail.
  let tailGlobal = response.hourly[response.hourly.count - 1][.gemGlobal]
  #expect(tailGlobal?.temperature != nil, "gem_global temperature should remain in the tail")
}

@Test func testSampleNewHourlyFieldsDecode() throws {
  let response = try loadSample()
  let gem = try #require(response.hourly[0][.gemGlobal])

  #expect(gem.apparentTemperature != nil, "apparentTemperature should decode")
  #expect(gem.dewPoint != nil, "dewPoint should decode")
  #expect(gem.relativeHumidity != nil, "relativeHumidity should decode")
  if let rh = gem.relativeHumidity {
    #expect(rh >= 0 && rh <= 100, "relativeHumidity should be 0-100")
  }
  #expect(gem.pressureMsl != nil, "pressureMsl should decode")
  #expect(gem.isDay != nil, "isDay should decode to a Bool")
}

@Test func testSampleDailyBlockDecodes() throws {
  let response = try loadSample()
  #expect(!response.daily.isEmpty, "daily block should decode")
  #expect(response.daily.count == 10, "should have 10 daily entries")

  let firstDay = try #require(response.daily[0][.gemGlobal])
  #expect(firstDay.temperatureMax != nil, "temperatureMax should decode")
  #expect(firstDay.temperatureMin != nil, "temperatureMin should decode")
  #expect(firstDay.sunrise != nil, "sunrise should decode to a Date")
  #expect(firstDay.sunset != nil, "sunset should decode to a Date")

  if let mx = firstDay.temperatureMax, let mn = firstDay.temperatureMin {
    #expect(mx >= mn, "max should be >= min")
  }

  // uv_index_max is requested + decoded for every day. The GEM models return it
  // null-valued (no UV product), so we assert the field decodes (no throw / present
  // model entry) rather than requiring a non-nil value.
  for day in response.daily {
    #expect(day[.gemGlobal] != nil, "each day should have a gem_global entry")
    // uvIndexMax is permitted to be nil for GEM models.
  }
}

@Test func testSampleUVIndexDecodesForUVCapableModel() async throws {
  // gfs_seamless does provide uv_index_max. Fetch a fresh sample to exercise a
  // non-nil UV value through the dynamic daily decoder.
  let client = OpenMeteoClient()
  let response = try await client.fetchWeatherData(
    latitude: 40.7128,
    longitude: -74.0060,
    models: [.gfsSeamless, .iconSeamless],
    dataTypes: .all,
    forecastDays: 3
  )
  #expect(!response.daily.isEmpty, "daily block should be present")
  let hasUV = response.daily.contains { $0[.gfsSeamless]?.uvIndexMax != nil }
  #expect(hasUV, "gfs_seamless should provide uv_index_max for at least one day")
}

@Test func testSampleDailySunriseBeforeSunset() throws {
  let response = try loadSample()
  let day = try #require(response.daily[0][.gemGlobal])
  if let sunrise = day.sunrise, let sunset = day.sunset {
    #expect(sunrise < sunset, "sunrise should come before sunset")
  }
}

// MARK: - Dynamic decoder edge cases (synthetic JSON)

@Test func testDynamicDecoderCastsIntFields() throws {
  // wind_direction, weather_code, cloud_cover, precipitation_probability, is_day
  // arrive as JSON numbers and must surface as the correct public types.
  let json = """
  {
    "latitude": 49.0, "longitude": -119.0,
    "generationtime_ms": 0.1, "utc_offset_seconds": 0,
    "timezone": "GMT", "timezone_abbreviation": "GMT", "elevation": 300.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_direction_10m_gem_global": "°",
      "weather_code_gem_global": "wmo code",
      "cloud_cover_gem_global": "%",
      "precipitation_probability_gem_global": "%",
      "is_day_gem_global": ""
    },
    "hourly": {
      "time": ["2026-06-20T00:00"],
      "wind_direction_10m_gem_global": [240],
      "weather_code_gem_global": [61],
      "cloud_cover_gem_global": [75],
      "precipitation_probability_gem_global": [80],
      "is_day_gem_global": [1]
    }
  }
  """
  let response = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: Data(json.utf8))
  let gem = try #require(response.hourly[0][.gemGlobal])
  #expect(gem.windDirection == 240)
  #expect(gem.weatherCode == 61)
  #expect(gem.cloudCover == 75)
  #expect(gem.precipitationProbability == 80)
  #expect(gem.isDay == true)
  // daily absent -> empty, no crash
  #expect(response.daily.isEmpty)
}

@Test func testDynamicDecoderHandlesNulls() throws {
  let json = """
  {
    "latitude": 49.0, "longitude": -119.0,
    "generationtime_ms": 0.1, "utc_offset_seconds": 0,
    "timezone": "GMT", "timezone_abbreviation": "GMT", "elevation": 300.0,
    "hourly_units": { "time": "iso8601", "temperature_2m_gem_global": "°C" },
    "hourly": {
      "time": ["2026-06-20T00:00", "2026-06-20T01:00"],
      "temperature_2m_gem_global": [12.5, null]
    }
  }
  """
  let response = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: Data(json.utf8))
  #expect(response.hourly[0][.gemGlobal]?.temperature == 12.5)
  #expect(response.hourly[1][.gemGlobal]?.temperature == nil)
}

// MARK: - Capability helpers

@Test func testMaxForecastDays() {
  #expect(WeatherModel.ecmwfIfs025.maxForecastDays == 15)
  #expect(WeatherModel.ecmwfAifs025.maxForecastDays == 15)
  #expect(WeatherModel.iconSeamless.maxForecastDays == 7)
  #expect(WeatherModel.gfsSeamless.maxForecastDays == 16)
  #expect(WeatherModel.hrrr.maxForecastDays == 2)
  #expect(WeatherModel.nbm.maxForecastDays == 11)
  #expect(WeatherModel.gemGlobal.maxForecastDays == 10)
  #expect(WeatherModel.gemRegional.maxForecastDays == 3)
  #expect(WeatherModel.gemHrdpsContinental.maxForecastDays == 2)
}

@Test func testStandaloneTenDayCapable() {
  #expect(WeatherModel.hrrr.standaloneTenDayCapable == false)
  #expect(WeatherModel.gemHrdpsContinental.standaloneTenDayCapable == false)
  #expect(WeatherModel.gemRegional.standaloneTenDayCapable == false)
  #expect(WeatherModel.gemGlobal.standaloneTenDayCapable == true)
  #expect(WeatherModel.gfsSeamless.standaloneTenDayCapable == true)
  #expect(WeatherModel.ecmwfIfs025.standaloneTenDayCapable == true)
  #expect(WeatherModel.nbm.standaloneTenDayCapable == true)
}

@Test func testIsHighResolution() {
  #expect(WeatherModel.hrrr.isHighResolution == true)
  #expect(WeatherModel.gemHrdpsContinental.isHighResolution == true)
  #expect(WeatherModel.gemRegional.isHighResolution == true)
  #expect(WeatherModel.nbm.isHighResolution == true)
  #expect(WeatherModel.gemGlobal.isHighResolution == false)
  #expect(WeatherModel.gfsSeamless.isHighResolution == false)
  #expect(WeatherModel.ecmwfIfs025.isHighResolution == false)
}

@Test func testTailModel() {
  // Vancouver: gemRegional + gemGlobal both available -> HRDPS tails to regional.
  let van = (lat: 49.2827, lon: -123.1207)
  #expect(WeatherModel.gemHrdpsContinental.tailModel(latitude: van.lat, longitude: van.lon) == .gemRegional)
  #expect(WeatherModel.gemRegional.tailModel(latitude: van.lat, longitude: van.lon) == .gemGlobal)

  // NYC (CONUS): HRRR tails to NBM (available), regional tails to global.
  let nyc = (lat: 40.7128, lon: -74.0060)
  #expect(WeatherModel.hrrr.tailModel(latitude: nyc.lat, longitude: nyc.lon) == .nbm)

  // Outside HRDPS regional coverage but still global: HRDPS falls back to global.
  // Far-north location outside the regional box used here only to exercise the fallback branch.
  let tokyo = (lat: 35.6762, lon: 139.6503)
  // gemRegional not available in Tokyo -> HRDPS tail falls back to gemGlobal.
  #expect(WeatherModel.gemHrdpsContinental.tailModel(latitude: tokyo.lat, longitude: tokyo.lon) == .gemGlobal)

  // Full-horizon models have no tail.
  #expect(WeatherModel.gemGlobal.tailModel(latitude: van.lat, longitude: van.lon) == nil)
  #expect(WeatherModel.gfsSeamless.tailModel(latitude: nyc.lat, longitude: nyc.lon) == nil)
}

// MARK: - Configurable client

@Test func testClientCustomBaseURLAndKeyDoNotCrash() {
  // Just verifies the new initializer signature is usable.
  let client = OpenMeteoClient(baseURL: "https://customer-api.open-meteo.com/v1", apiKey: "test-key")
  #expect(client != nil)
}
