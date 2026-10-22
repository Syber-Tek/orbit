package com.example.orbit

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray

/**
 * Type-tolerant reads from `FlutterSharedPreferences`.
 *
 * shared_preferences_android persists Dart ints as Long and Dart doubles as
 * Double, so a naive getInt()/getLong() on a Flutter-stored value throws a
 * ClassCastException that callers end up swallowing with a default. These
 * helpers try every numeric representation so native code always sees the
 * value the user actually configured.
 */
object FlutterPrefs {

    private const val TAG = "FlutterPrefs"

    /** Dart-owned task list key (shared_preferences prefixes with `flutter.`). */
    private const val TASKS_KEY = "flutter.orbit.tasks.v1"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun getInt(context: Context, key: String, default: Int): Int =
        readNumber(context, "flutter.$key")?.toInt() ?: default

    fun getLong(context: Context, key: String, default: Long): Long =
        readNumber(context, "flutter.$key")?.toLong() ?: default

    private fun readNumber(context: Context, prefixedKey: String): Number? {
        val p = prefs(context)
        if (!p.contains(prefixedKey)) return null
        tryGetInt(p, prefixedKey)?.let { return it }
        tryGetLong(p, prefixedKey)?.let { return it }
        tryGetFloat(p, prefixedKey)?.let { return it }
        return try {
            p.getString(prefixedKey, null)?.toDoubleOrNull()
        } catch (_: Throwable) {
            null
        }
    }

    private fun tryGetInt(p: SharedPreferences, key: String): Int? = try {
        p.getInt(key, Int.MIN_VALUE).takeIf { it != Int.MIN_VALUE }
    } catch (_: Throwable) {
        null
    }

    private fun tryGetLong(p: SharedPreferences, key: String): Long? = try {
        p.getLong(key, Long.MIN_VALUE).takeIf { it != Long.MIN_VALUE }
    } catch (_: Throwable) {
        null
    }

    private fun tryGetFloat(p: SharedPreferences, key: String): Float? = try {
        p.getFloat(key, Float.NaN).takeIf { !it.isNaN() }
    } catch (_: Throwable) {
        null
    }

    /**
     * Marks [taskId] completed directly in the Dart-owned task list so a native
     * action (the ring notification's "Mark done") never has to launch the app.
     * Returns true when the stored JSON actually changed.
     */
    fun markTaskCompleted(context: Context, taskId: String): Boolean {
        return try {
            val p = prefs(context)
            val raw = p.getString(TASKS_KEY, null)
            if (raw == null) {
                false
            } else {
                val arr = JSONArray(raw)
                var changed = false
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    if (o.optString("id") == taskId) {
                        if (!o.optBoolean("isCompleted", false)) {
                            o.put("isCompleted", true)
                            changed = true
                        }
                        break
                    }
                }
                if (changed) {
                    p.edit().putString(TASKS_KEY, arr.toString()).apply()
                }
                changed
            }
        } catch (t: Throwable) {
            Log.w(TAG, "markTaskCompleted failed for $taskId", t)
            false
        }
    }
}
