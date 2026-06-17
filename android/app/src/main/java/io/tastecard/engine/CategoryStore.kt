package io.tastecard.engine

import android.content.Context
import io.tastecard.model.Category
import org.json.JSONObject

/** Loads + validates the bundled category dataset (§6). Refuses malformed data. */
object CategoryStore {
    const val SUPPORTED_VERSION = 1

    class InvalidDatasetException(message: String) : Exception(message)

    fun loadFromAssets(context: Context, name: String = "categories.json"): List<Category> {
        val text = context.assets.open(name).bufferedReader().use { it.readText() }
        return parse(text)
    }

    fun parse(json: String): List<Category> {
        val root = JSONObject(json)
        val version = root.optInt("version", -1)
        if (version != SUPPORTED_VERSION) throw InvalidDatasetException("unsupported version $version")

        val arr = root.optJSONArray("categories")
            ?: throw InvalidDatasetException("missing categories array")
        if (arr.length() == 0) throw InvalidDatasetException("no categories present")

        val seen = HashSet<String>()
        val out = ArrayList<Category>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val id = o.optString("id")
            if (id.isEmpty()) throw InvalidDatasetException("empty category id")
            if (!seen.add(id)) throw InvalidDatasetException("duplicate category id $id")

            val displayName = o.optString("displayName")
            if (displayName.isEmpty()) throw InvalidDatasetException("$id: empty displayName")

            val promptsArr = o.optJSONArray("detectionPrompts")
            val prompts = ArrayList<String>()
            if (promptsArr != null) for (j in 0 until promptsArr.length()) prompts.add(promptsArr.getString(j))
            if (prompts.isEmpty()) throw InvalidDatasetException("$id: no detection prompts")

            val rarityIndex = o.optDouble("rarityIndex", -1.0)
            if (rarityIndex < 0.0 || rarityIndex > 1.0) throw InvalidDatasetException("$id: rarityIndex out of range")

            val threshold = o.optDouble("threshold", -1.0)
            if (threshold <= 0.0 || threshold > 1.0) throw InvalidDatasetException("$id: threshold out of range")

            out.add(Category(id, displayName, o.optString("tagline"), prompts, rarityIndex, threshold))
        }
        return out
    }
}
