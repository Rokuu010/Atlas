package io.tastecard.persistence

import android.content.Context
import io.tastecard.model.EmergentTheme
import io.tastecard.model.Rarity
import io.tastecard.model.RarityTier
import io.tastecard.model.Tastecard
import org.json.JSONArray
import org.json.JSONObject

/** Persists ONLY the derived, non-identifying card (§5/§8) in SharedPreferences. */
class CardStore(context: Context) {
    private val prefs = context.getSharedPreferences("tastecard", Context.MODE_PRIVATE)

    fun load(): Tastecard? {
        val s = prefs.getString(KEY, null) ?: return null
        return try { fromJson(JSONObject(s)) } catch (e: Exception) { null }
    }

    fun save(card: Tastecard) {
        prefs.edit().putString(KEY, toJson(card).toString()).apply()
    }

    fun clear() {
        prefs.edit().remove(KEY).apply()
    }

    private fun toJson(card: Tastecard): JSONObject {
        val themes = JSONArray()
        for (t in card.themes) {
            themes.put(
                JSONObject()
                    .put("categoryId", t.categoryId)
                    .put("displayName", t.displayName)
                    .put("tagline", t.tagline)
                    .put("photoCount", t.photoCount)
                    .put("rarityIndex", t.rarityIndex)
                    .put("rarityTier", t.rarityTier.name)
                    .put("heroPhotoUri", t.heroPhotoUri ?: JSONObject.NULL)
            )
        }
        return JSONObject()
            .put("id", card.id)
            .put("displayName", card.displayName)
            .put("themeIndex", card.themeIndex)
            .put("heroPhotoUri", card.heroPhotoUri ?: JSONObject.NULL)
            .put("photosAnalysed", card.photosAnalysed)
            .put("emergentThemeCount", card.emergentThemeCount)
            .put("placesCount", card.placesCount)
            .put("cardRarity", card.cardRarity.name)
            .put("createdAt", card.createdAt)
            .put("themes", themes)
    }

    private fun fromJson(o: JSONObject): Tastecard {
        val themesArr = o.getJSONArray("themes")
        val themes = ArrayList<EmergentTheme>(themesArr.length())
        for (i in 0 until themesArr.length()) {
            val t = themesArr.getJSONObject(i)
            themes.add(
                EmergentTheme(
                    categoryId = t.getString("categoryId"),
                    displayName = t.getString("displayName"),
                    tagline = t.getString("tagline"),
                    photoCount = t.getInt("photoCount"),
                    rarityIndex = t.getDouble("rarityIndex"),
                    rarityTier = runCatching { RarityTier.valueOf(t.getString("rarityTier")) }
                        .getOrElse { Rarity.tier(t.getDouble("rarityIndex")) },
                    heroPhotoUri = if (t.isNull("heroPhotoUri")) null else t.getString("heroPhotoUri"),
                )
            )
        }
        return Tastecard(
            id = o.getString("id"),
            displayName = o.getString("displayName"),
            themeIndex = o.getInt("themeIndex"),
            heroPhotoUri = if (o.isNull("heroPhotoUri")) null else o.getString("heroPhotoUri"),
            photosAnalysed = o.getInt("photosAnalysed"),
            emergentThemeCount = o.getInt("emergentThemeCount"),
            placesCount = o.getInt("placesCount"),
            cardRarity = runCatching { RarityTier.valueOf(o.getString("cardRarity")) }.getOrElse { RarityTier.COMMON },
            themes = themes,
            createdAt = o.optLong("createdAt", System.currentTimeMillis()),
        )
    }

    companion object {
        private const val KEY = "currentCard.v1"
    }
}
