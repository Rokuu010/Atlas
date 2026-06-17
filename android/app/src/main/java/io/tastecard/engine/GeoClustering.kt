package io.tastecard.engine

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Pure greedy GPS clustering -> Places count (§6). Ported from the iOS GeoClustering. */
object GeoClustering {
    data class Coordinate(val latitude: Double, val longitude: Double)

    fun distanceMeters(a: Coordinate, b: Coordinate): Double {
        val earth = 6_371_000.0
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * asin(min(1.0, sqrt(h)))
    }

    fun placesCount(coordinates: List<Coordinate>, radiusMeters: Double = 25_000.0): Int {
        if (coordinates.isEmpty()) return 0
        val sorted = coordinates.sortedWith(
            compareBy({ it.latitude }, { it.longitude })
        )
        val centroids = mutableListOf<Coordinate>()
        for (coord in sorted) {
            if (centroids.any { distanceMeters(it, coord) <= radiusMeters }) continue
            centroids.add(coord)
        }
        return centroids.size
    }
}
