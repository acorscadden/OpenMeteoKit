//
//  IntegrationTests.swift
//  OpenMeteoKit
//
//  Created by Adrian Corscadden on 2025-06-24.
//

import XCTest
import Testing
import Foundation
@testable import OpenMeteoKit

@Test func testFetchVancouverWeather() async throws {
  let client = OpenMeteoClient()

  // Vancouver coordinates
  let latitude: Double = 49.2827
  let longitude: Double = -123.1207

  do {
    let response = try await client.fetchWeatherData(
      latitude: latitude,
      longitude: longitude,
      models: [.ecmwfIfs025, .iconSeamless, .gemHrdpsContinental],
      windSpeedUnit: .knots
    )

    // Verify response has data
    #expect(!response.hourly.isEmpty, "Hourly data should not be empty")

    // Verify we have data for each requested model
    let firstHour = response.hourly.first!

    #expect(firstHour[.ecmwfIfs025] != nil, "ECMWF model data should be present")
    #expect(firstHour[.iconSeamless] != nil, "ICON model data should be present")
    #expect(firstHour[.gemHrdpsContinental] != nil, "GEM-HRDPS model data should be present")

    // Verify wind data is present for each model
    if let ecmwfData = firstHour[.ecmwfIfs025] {
      #expect(ecmwfData.windSpeed != nil, "ECMWF wind speed should be present")
      #expect(ecmwfData.windDirection != nil, "ECMWF wind direction should be present")
    }

    if let iconData = firstHour[.iconSeamless] {
      #expect(iconData.windSpeed != nil, "ICON wind speed should be present")
      #expect(iconData.windDirection != nil, "ICON wind direction should be present")
    }

    if let gemData = firstHour[.gemHrdpsContinental] {
      #expect(gemData.windSpeed != nil, "GEM-HRDPS wind speed should be present")
      #expect(gemData.windDirection != nil, "GEM-HRDPS wind direction should be present")
    }

    print("✅ Successfully fetched Vancouver weather data for \(response.hourly.count) hours")

    // Verify precipitation data is present
    if let ecmwfData = firstHour[.ecmwfIfs025] {
      // Precipitation fields should exist (may be nil if no precip, but the field should decode)
      #expect(ecmwfData.precipitationUnit == "mm", "Precipitation unit should be mm")
      #expect(ecmwfData.snowfallUnit == "cm", "Snowfall unit should be cm")
      #expect(ecmwfData.precipitationProbabilityUnit == "%", "Precipitation probability unit should be %")
    }

    if let iconData = firstHour[.iconSeamless] {
      #expect(iconData.precipitationUnit == "mm", "ICON precipitation unit should be mm")
    }

    // Verify weather code is present
    if let ecmwfData = firstHour[.ecmwfIfs025] {
      #expect(ecmwfData.weatherCodeUnit == "wmo code", "Weather code unit should be 'wmo code'")
      // Weather code should be a valid WMO code (0-99 range)
      if let code = ecmwfData.weatherCode {
        #expect(code >= 0 && code <= 99, "Weather code should be in valid WMO range")
      }
    }

    print("✅ Precipitation and weather code data verified")

  } catch {
    print("❌ Error fetching Vancouver weather data: \(error)")
    throw error
  }
}

@Test func testFetchPrecipitationOnly() async throws {
  let client = OpenMeteoClient()

  let latitude: Double = 49.2827
  let longitude: Double = -123.1207

  do {
    let response = try await client.fetchWeatherData(
      latitude: latitude,
      longitude: longitude,
      models: [.iconSeamless],
      dataTypes: .precipitation
    )

    #expect(!response.hourly.isEmpty, "Hourly data should not be empty")

    let firstHour = response.hourly.first!
    if let iconData = firstHour[.iconSeamless] {
      // Precipitation data should be present
      #expect(iconData.precipitationUnit == "mm", "Precipitation unit should be mm")
      #expect(iconData.weatherCodeUnit == "wmo code", "Weather code unit should be present")

      // Wind data should be nil since we only requested precipitation
      #expect(iconData.windSpeed == nil, "Wind speed should be nil when only precipitation requested")
      #expect(iconData.windDirection == nil, "Wind direction should be nil when only precipitation requested")
    }

    print("✅ Precipitation-only fetch verified")

  } catch {
    print("❌ Error fetching precipitation-only data: \(error)")
    throw error
  }
}

@Test func testFetchWindOnly() async throws {
  let client = OpenMeteoClient()

  let latitude: Double = 49.2827
  let longitude: Double = -123.1207

  do {
    let response = try await client.fetchWeatherData(
      latitude: latitude,
      longitude: longitude,
      models: [.ecmwfIfs025, .iconSeamless],
      dataTypes: .wind
    )

    #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
    print("📊 Received \(response.hourly.count) hours of data")

    // Check first hour data
    let firstHour = response.hourly.first!
    if let ecmwfData = firstHour[.ecmwfIfs025] {
      // Precipitation data should be nil since we only requested wind
      #expect(ecmwfData.precipitation == nil, "Precipitation should be nil when only wind requested")
      #expect(ecmwfData.weatherCode == nil, "Weather code should be nil when only wind requested")
      print("✅ Precipitation correctly nil for wind-only request")
    }

    print("✅ Wind-only fetch verified")

  } catch {
    print("❌ Error fetching wind-only data: \(error)")
    throw error
  }
}

// MARK: - Individual Model Tests
// Note: When querying a single model, the API doesn't suffix field names.
// We query with 2 models to ensure model-specific keys are returned.

@Test func testGfsSeamlessModel() async throws {
  let client = OpenMeteoClient()
  let response = try await client.fetchWeatherData(
    latitude: 40.7128,
    longitude: -74.0060,
    models: [.gfsSeamless, .iconSeamless]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.gfsSeamless]
  #expect(data != nil, "GFS Seamless model data should be present")
  #expect(data?.windSpeed != nil, "GFS wind speed should be present")
  print("✅ GFS Seamless model verified")
}

@Test func testHrrrModel() async throws {
  let client = OpenMeteoClient()
  // HRRR only covers CONUS, use US coordinates
  let response = try await client.fetchWeatherData(
    latitude: 40.7128,
    longitude: -74.0060,
    models: [.hrrr, .gfsSeamless]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.hrrr]
  #expect(data != nil, "HRRR model data should be present")
  #expect(data?.windSpeed != nil, "HRRR wind speed should be present")
  print("✅ HRRR model verified")
}

@Test func testNbmModel() async throws {
  let client = OpenMeteoClient()
  // NBM only covers CONUS, use US coordinates
  let response = try await client.fetchWeatherData(
    latitude: 40.7128,
    longitude: -74.0060,
    models: [.nbm, .gfsSeamless]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.nbm]
  #expect(data != nil, "NBM model data should be present")
  #expect(data?.windSpeed != nil, "NBM wind speed should be present")
  print("✅ NBM model verified")
}

@Test func testEcmwfAifsModel() async throws {
  let client = OpenMeteoClient()
  let response = try await client.fetchWeatherData(
    latitude: 52.52,
    longitude: 13.405,
    models: [.ecmwfAifs025, .ecmwfIfs025]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.ecmwfAifs025]
  #expect(data != nil, "ECMWF AIFS model data should be present")
  // Note: AIFS is an AI model and may have null values for some hours
  print("✅ ECMWF AIFS model verified")
}

@Test func testGemGlobalModel() async throws {
  let client = OpenMeteoClient()
  let response = try await client.fetchWeatherData(
    latitude: 45.4215,
    longitude: -75.6972,
    models: [.gemGlobal, .gemRegional]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.gemGlobal]
  #expect(data != nil, "GEM Global model data should be present")
  #expect(data?.windSpeed != nil, "GEM Global wind speed should be present")
  print("✅ GEM Global model verified")
}

@Test func testGemRegionalModel() async throws {
  let client = OpenMeteoClient()
  // GEM Regional covers North America
  let response = try await client.fetchWeatherData(
    latitude: 45.4215,
    longitude: -75.6972,
    models: [.gemRegional, .gemGlobal]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!
  let data = firstHour[.gemRegional]
  #expect(data != nil, "GEM Regional model data should be present")
  #expect(data?.windSpeed != nil, "GEM Regional wind speed should be present")
  print("✅ GEM Regional model verified")
}

@Test func testAllModelsAtOnce() async throws {
  let client = OpenMeteoClient()
  // Use US coordinates since some models only cover CONUS
  let response = try await client.fetchWeatherData(
    latitude: 40.7128,
    longitude: -74.0060,
    models: [
      .ecmwfIfs025,
      .ecmwfAifs025,
      .iconSeamless,
      .gfsSeamless,
      .hrrr,
      .nbm,
      .gemGlobal,
      .gemRegional,
      .gemHrdpsContinental
    ]
  )

  #expect(!response.hourly.isEmpty, "Hourly data should not be empty")
  let firstHour = response.hourly.first!

  // Verify each model has data
  #expect(firstHour[.ecmwfIfs025] != nil, "ECMWF IFS should be present")
  #expect(firstHour[.ecmwfAifs025] != nil, "ECMWF AIFS should be present")
  #expect(firstHour[.iconSeamless] != nil, "ICON should be present")
  #expect(firstHour[.gfsSeamless] != nil, "GFS should be present")
  #expect(firstHour[.hrrr] != nil, "HRRR should be present")
  #expect(firstHour[.nbm] != nil, "NBM should be present")
  #expect(firstHour[.gemGlobal] != nil, "GEM Global should be present")
  #expect(firstHour[.gemRegional] != nil, "GEM Regional should be present")
  #expect(firstHour[.gemHrdpsContinental] != nil, "GEM HRDPS should be present")

  print("✅ All 9 models fetched successfully")
}
