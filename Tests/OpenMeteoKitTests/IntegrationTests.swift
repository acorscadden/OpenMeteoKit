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
      models: [.ecmwfIfs025, .iconSeamless, .gem_hrdps_continental],
      windSpeedUnit: .knots
    )

    // Verify response has data
    #expect(!response.hourly.isEmpty, "Hourly data should not be empty")

    // Verify we have data for each requested model
    let firstHour = response.hourly.first!

    #expect(firstHour[.ecmwfIfs025] != nil, "ECMWF model data should be present")
    #expect(firstHour[.iconSeamless] != nil, "ICON model data should be present")
    #expect(firstHour[.gem_hrdps_continental] != nil, "GEM-HRDPS model data should be present")

    // Verify wind data is present for each model
    if let ecmwfData = firstHour[.ecmwfIfs025] {
      #expect(ecmwfData.windSpeed != nil, "ECMWF wind speed should be present")
      #expect(ecmwfData.windDirection != nil, "ECMWF wind direction should be present")
    }

    if let iconData = firstHour[.iconSeamless] {
      #expect(iconData.windSpeed != nil, "ICON wind speed should be present")
      #expect(iconData.windDirection != nil, "ICON wind direction should be present")
    }

    if let gemData = firstHour[.gem_hrdps_continental] {
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
