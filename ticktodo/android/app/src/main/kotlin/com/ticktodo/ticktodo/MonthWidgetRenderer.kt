package com.ticktodo.ticktodo

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

/**
 * 月视图小部件渲染器：读库 → 构建 RemoteViews。
 * 所有数据来自 Flutter sqflite 的 ticktodo.db（只读打开）。
 */
object MonthWidgetRenderer {

    private val dateFmt = DateTimeFormatter.ofPattern("yyyy-MM-dd")

    /** 当月有未完成任务（且未删除）的日期集合。 */
    fun loadTaskDates(context: Context, month: YearMonth): Set<String> {
        val result = mutableSetOf<String>()
        val dbFile = context.getDatabasePath("ticktodo.db")
        if (!dbFile.exists()) return result
        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY
            )
            val start = month.atDay(1).format(dateFmt)
            val end = month.atEndOfMonth().format(dateFmt)
            val cursor = db.rawQuery(
                "SELECT dueDate FROM tasks WHERE deletedAt IS NULL AND completed = 0 AND dueDate >= ? AND dueDate <= ?",
                arrayOf(start, end)
            )
            while (cursor.moveToNext()) {
                cursor.getString(0)?.let { result.add(it) }
            }
            cursor.close()
        } catch (e: Exception) {
            // 数据库被占用/未初始化等：返回空集合，不崩溃
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
        return result
    }

    /**
     * 构建月视图 RemoteViews。
     * @param offset 相对当前月份的偏移（-1=上月，1=下月）
     */
    fun build(context: Context, offset: Int): RemoteViews {
        val today = LocalDate.now()
        val month = YearMonth.now().plusMonths(offset.toLong())
        val taskDates = loadTaskDates(context, month)
        val views = RemoteViews(context.packageName, R.layout.month_widget)

        // 头部
        views.setTextViewText(R.id.widget_month, "${month.year}年${month.monthValue}月")
        views.setViewVisibility(R.id.widget_today_btn, if (offset == 0) View.GONE else View.VISIBLE)
        views.setOnClickPendingIntent(R.id.widget_prev, pendingAction(context, MonthWidgetProvider.ACTION_PREV, 10))
        views.setOnClickPendingIntent(R.id.widget_next, pendingAction(context, MonthWidgetProvider.ACTION_NEXT, 11))
        views.setOnClickPendingIntent(R.id.widget_refresh, pendingAction(context, MonthWidgetProvider.ACTION_REFRESH, 12))
        views.setOnClickPendingIntent(R.id.widget_today_btn, pendingAction(context, MonthWidgetProvider.ACTION_TODAY, 13))

        // 网格：6 行 × 7 列
        val gridId = R.id.widget_grid
        views.removeAllViews(gridId)
        val firstDay = month.atDay(1)
        val leadingBlanks = firstDay.dayOfWeek.value - 1 // 周一起始
        val daysInMonth = month.lengthOfMonth()
        val cells = leadingBlanks + daysInMonth
        val rowCount = (cells + 6) / 7

        for (row in 0 until rowCount) {
            val rowView = RemoteViews(context.packageName, R.layout.month_widget_row)
            for (col in 0 until 7) {
                val index = row * 7 + col
                val cell = RemoteViews(context.packageName, R.layout.month_widget_cell)
                val day = index - leadingBlanks + 1
                if (day < 1 || day > daysInMonth) {
                    cell.setTextViewText(R.id.widget_cell_day, "")
                    cell.setViewVisibility(R.id.widget_cell_dot, View.INVISIBLE)
                } else {
                    val date = month.atDay(day)
                    val isToday = date == today
                    val hasTask = date.format(dateFmt) in taskDates
                    cell.setTextViewText(R.id.widget_cell_day, day.toString())
                    if (isToday) {
                        cell.setInt(R.id.widget_cell_day, "setBackgroundResource", R.drawable.widget_today_bg)
                        cell.setTextColor(R.id.widget_cell_day, context.getColor(R.color.widget_today_text))
                    } else {
                        cell.setTextColor(R.id.widget_cell_day, context.getColor(R.color.widget_text))
                    }
                    cell.setViewVisibility(R.id.widget_cell_dot, if (hasTask) View.VISIBLE else View.INVISIBLE)
                    cell.setOnClickPendingIntent(R.id.widget_cell_day, openDate(context, date.format(dateFmt), index))
                }
                rowView.addView(R.layout.month_widget_cell, cell)
            }
            views.addView(gridId, rowView)
        }
        return views
    }

    private fun pendingAction(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MonthWidgetProvider::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun openDate(context: Context, date: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .putExtra(MainActivity.EXTRA_DATE, date)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
