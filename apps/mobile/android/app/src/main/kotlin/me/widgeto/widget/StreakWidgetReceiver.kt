package me.widgeto.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.sqrt

/**
 * The Android home-screen face.
 *
 * Like the iOS extension, this never fetches or computes — the Flutter app has
 * already written a finished payload via home_widget. RemoteViews cannot draw
 * 140 individual views cheaply, so the contribution grid is rendered once into
 * a Bitmap and handed over as a single ImageView.
 */
class StreakWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)

        val streak = data.getInt("streak", 0)
        val status = data.getString("status", "broken") ?: "broken"
        val grid = data.getString("grid", "") ?: ""

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.streak_value, streak.toString())
                setTextViewText(R.id.streak_status, statusLabel(status))
                setTextColor(R.id.streak_status, statusColor(status))
                setImageViewBitmap(R.id.streak_grid, renderGrid(grid, weeks = 20))

                // Tapping the widget opens the app.
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                    setOnClickPendingIntent(
                        R.id.widget_root,
                        PendingIntent.getActivity(
                            context, 0, it,
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                        ),
                    )
                }
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun statusLabel(status: String) = when (status) {
        "safe" -> "done today"
        "at-risk" -> "not yet today"
        else -> "streak broken"
    }

    private fun statusColor(status: String) = when (status) {
        "safe" -> COLOR_GITHUB
        "at-risk" -> COLOR_FLAME
        else -> COLOR_DANGER
    }

    /**
     * Decode the `LP`-pair grid string and paint it.
     * L is intensity 0-4, P is the dominant platform (g/c/l) or `-` when idle.
     */
    private fun renderGrid(raw: String, weeks: Int): Bitmap {
        val cell = 12f
        val gap = 3f
        val cols = weeks
        val width = (cols * (cell + gap)).toInt().coerceAtLeast(1)
        val height = (7 * (cell + gap)).toInt().coerceAtLeast(1)

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Keep only the most recent `weeks` of days.
        val pairs = raw.chunked(2).takeLast(cols * 7)

        for ((index, pair) in pairs.withIndex()) {
            if (pair.length < 2) continue
            val level = pair[0].digitToIntOrNull() ?: 0
            val platform = pair[1]

            val col = index / 7
            val row = index % 7
            paint.color = cellColor(level, platform)

            val left = col * (cell + gap)
            val top = row * (cell + gap)
            canvas.drawRoundRect(RectF(left, top, left + cell, top + cell), 3f, 3f, paint)
        }
        return bitmap
    }

    private fun cellColor(level: Int, platform: Char): Int {
        if (level <= 0) return COLOR_EMPTY
        val target = when (platform) {
            'g' -> COLOR_GITHUB
            'c' -> COLOR_CODEFORCES
            'l' -> COLOR_LEETCODE
            else -> COLOR_EMPTY
        }
        // Same intensity floor as the web and iOS, so all three faces match.
        val t = 0.25f + 0.75f * sqrt(level / 4f)
        return blend(COLOR_EMPTY, target, t)
    }

    private fun blend(from: Int, to: Int, t: Float): Int = Color.rgb(
        (Color.red(from) + (Color.red(to) - Color.red(from)) * t).toInt(),
        (Color.green(from) + (Color.green(to) - Color.green(from)) * t).toInt(),
        (Color.blue(from) + (Color.blue(to) - Color.blue(from)) * t).toInt(),
    )

    private companion object {
        const val COLOR_EMPTY = 0xFF1A1E26.toInt()
        const val COLOR_GITHUB = 0xFF39D353.toInt()
        const val COLOR_CODEFORCES = 0xFF4AA3E0.toInt()
        const val COLOR_LEETCODE = 0xFFFFA116.toInt()
        const val COLOR_FLAME = 0xFFFFB43D.toInt()
        const val COLOR_DANGER = 0xFFFF5C5C.toInt()
    }
}
