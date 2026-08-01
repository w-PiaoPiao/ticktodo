package com.ticktodo.ticktodo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * 月视图桌面小部件 Provider。
 * 支持：手动刷新、左右切月、回今天、点击日期打开应用。
 */
class MonthWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV = "com.ticktodo.ticktodo.WIDGET_PREV"
        const val ACTION_NEXT = "com.ticktodo.ticktodo.WIDGET_NEXT"
        const val ACTION_TODAY = "com.ticktodo.ticktodo.WIDGET_TODAY"
        const val ACTION_REFRESH = "com.ticktodo.ticktodo.WIDGET_REFRESH"

        private const val PREFS = "widget_prefs"
        private const val KEY_OFFSET = "month_offset"

        fun getOffset(context: Context): Int =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_OFFSET, 0)

        private fun setOffset(context: Context, offset: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putInt(KEY_OFFSET, offset).apply()
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MonthWidgetProvider::class.java)
            )
            for (id in ids) {
                manager.updateAppWidget(
                    id, MonthWidgetRenderer.build(context, getOffset(context))
                )
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id, MonthWidgetRenderer.build(context, getOffset(context))
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PREV -> setOffset(context, getOffset(context) - 1)
            ACTION_NEXT -> setOffset(context, getOffset(context) + 1)
            ACTION_TODAY -> setOffset(context, 0)
            ACTION_REFRESH -> Unit
            else -> return
        }
        refreshAll(context)
    }
}
