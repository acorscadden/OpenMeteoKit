import Testing
import Foundation
@testable import OpenMeteoKit

// MARK: - Real-sample ensemble decode tests

private func loadEnsembleSample() throws -> EnsembleResponse {
  let url = try #require(
    Bundle.module.url(forResource: "ensemble_gfs025_sample", withExtension: "json"),
    "ensemble_gfs025_sample.json must be bundled as a test resource"
  )
  let data = try Data(contentsOf: url)
  // Decode through the exact same path the client uses.
  let raw = try JSONDecoder().decode(RawEnsembleResponse.self, from: data)
  return EnsembleResponse.from(raw: raw, variable: .temperature2m)
}

@Test func testEnsembleControlSeriesPresentAndNonEmpty() throws {
  let r = try loadEnsembleSample()
  #expect(!r.time.isEmpty, "time series should be non-empty")
  #expect(r.control.count == r.time.count, "control series length should match time")
  #expect(r.control.contains { $0 != nil }, "control series should have values")
}

@Test func testEnsembleHas30Members() throws {
  let r = try loadEnsembleSample()
  #expect(r.members.count == 30, "gfs025 single-model should decode 30 perturbed members")
}

@Test func testEnsembleMemberAndTimeCountsConsistent() throws {
  let r = try loadEnsembleSample()
  for (i, member) in r.members.enumerated() {
    #expect(member.count == r.time.count, "member \(i) length should equal time count")
  }
}

@Test func testEnsembleP50WithinMemberMinMax() throws {
  let r = try loadEnsembleSample()
  let p50 = r.percentiles([50])[0]

  // Find a timestep where members have values, then assert p50 is within range.
  var checked = 0
  for t in 0..<r.time.count {
    let vals = r.members.compactMap { $0.indices.contains(t) ? $0[t] : nil }
    guard vals.count > 1 else { continue }
    let median = try #require(p50[t], "p50 should be non-nil where members have values")
    #expect(median >= vals.min()!, "p50 should be >= member min at t=\(t)")
    #expect(median <= vals.max()!, "p50 should be <= member max at t=\(t)")
    checked += 1
    if checked >= 5 { break }
  }
  #expect(checked > 0, "should have at least one timestep with multiple member values")
}

// MARK: - Percentile unit tests (synthetic)

@Test func testInterpolatedQuantileBasics() {
  let sorted = [0.0, 10.0, 20.0, 30.0, 40.0]
  #expect(EnsembleResponse.interpolatedQuantile(sorted: sorted, percentile: 0) == 0.0)
  #expect(EnsembleResponse.interpolatedQuantile(sorted: sorted, percentile: 100) == 40.0)
  #expect(EnsembleResponse.interpolatedQuantile(sorted: sorted, percentile: 50) == 20.0)
  // p25 over 5 values: rank = 0.25 * 4 = 1.0 -> exactly index 1 = 10
  #expect(EnsembleResponse.interpolatedQuantile(sorted: sorted, percentile: 25) == 10.0)
  // interpolation: p10 -> rank 0.4 -> between 0 and 10 -> 4.0
  #expect(EnsembleResponse.interpolatedQuantile(sorted: sorted, percentile: 10) == 4.0)
}

@Test func testPercentilesHandleNilTimesteps() {
  // Two members, one timestep all-nil.
  let r = EnsembleResponse(
    time: [Date(), Date(timeIntervalSince1970: 3600)],
    control: [1.0, 2.0],
    members: [[10.0, nil], [20.0, nil]],
    unit: "°C"
  )
  let p = r.percentiles([50])
  #expect(p[0][0] == 15.0, "p50 of [10,20] should be 15")
  #expect(p[0][1] == nil, "all-nil timestep should yield nil")
}

// MARK: - Live fetch (network)

@Test func testFetchEnsembleLive() async throws {
  let client = OpenMeteoClient()
  let r = try await client.fetchEnsemble(
    latitude: 49.45,
    longitude: -119.59,
    model: .gfs025,
    variable: .temperature2m,
    forecastDays: 7
  )
  #expect(!r.time.isEmpty)
  #expect(r.members.count == 30, "gfs025 should return 30 members live")
  #expect(r.control.contains { $0 != nil })
  #expect(r.unit == "°C")
}
