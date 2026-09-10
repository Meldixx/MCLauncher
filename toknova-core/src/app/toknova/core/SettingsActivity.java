package app.toknova.core;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;

public final class SettingsActivity extends Activity {
    private SharedPreferences prefs;
    private LinearLayout content;

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        prefs = getSharedPreferences(TokNovaCore.PREFS, MODE_PRIVATE);
        getWindow().setStatusBarColor(0xFF08090D);
        getWindow().setNavigationBarColor(0xFF08090D);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(0xFF08090D);

        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(20), dp(22), dp(20), dp(32));
        scroll.addView(content, new ScrollView.LayoutParams(-1, -2));

        TextView title = text("TokNova Settings", 28f, Color.WHITE, true);
        content.addView(title);
        TextView subtitle = text("TokNova Core 0.1.0  •  TikTok 46.9.42", 13f, 0xFF8F97A8, false);
        LinearLayout.LayoutParams subLp = new LinearLayout.LayoutParams(-1, -2);
        subLp.topMargin = dp(4);
        subLp.bottomMargin = dp(22);
        content.addView(subtitle, subLp);

        section("ИНТЕРФЕЙС");
        toggle("Кнопка TokNova", "Показывать плавающую кнопку настроек в TikTok", "core_button", true);
        toggle("Скрыть LIVE", "Скрывает элементы интерфейса с пометкой LIVE", "hide_live", false);
        toggle("Скрыть Shop", "Скрывает вкладки и кнопки TikTok Shop", "hide_shop", false);
        toggle("Скрыть Друзья", "Убирает вкладку Friends / Друзья", "hide_friends", false);

        section("ПРОСМОТР");
        toggle("Focus Mode", "Скрывает Like / Comments / Share / Repost по content description", "focus_mode", false);

        section("TOKNOVA CORE");
        info("Это первая чистая сборка TokNova. Здесь нет Morphe, Metra или их runtime. Низкоуровневые патчи плеера, ленты и загрузок будут переноситься в TokNova Core отдельно и по одному.");

        Button reset = new Button(this);
        reset.setText("Сбросить настройки TokNova");
        reset.setAllCaps(false);
        reset.setTextColor(Color.WHITE);
        reset.setTextSize(15f);
        GradientDrawable rb = new GradientDrawable();
        rb.setCornerRadius(dp(14));
        rb.setColor(0xFF1A1C24);
        rb.setStroke(dp(1), 0xFF343846);
        reset.setBackground(rb);
        LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(-1, dp(52));
        rlp.topMargin = dp(20);
        content.addView(reset, rlp);
        reset.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                prefs.edit().clear().apply();
                recreate();
            }
        });

        setContentView(scroll);
    }

    private TextView text(String value, float size, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(value);
        v.setTextSize(size);
        v.setTextColor(color);
        if (bold) v.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return v;
    }

    private void section(String name) {
        TextView v = text(name, 12f, 0xFF42E8E0, true);
        v.setLetterSpacing(0.08f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(18);
        lp.bottomMargin = dp(8);
        content.addView(v, lp);
    }

    private void info(String body) {
        TextView v = text(body, 14f, 0xFFB8BFCC, false);
        v.setLineSpacing(0f, 1.15f);
        v.setPadding(dp(14), dp(14), dp(14), dp(14));
        GradientDrawable bg = new GradientDrawable();
        bg.setCornerRadius(dp(16));
        bg.setColor(0xFF11131A);
        bg.setStroke(dp(1), 0xFF262A35);
        v.setBackground(bg);
        content.addView(v, new LinearLayout.LayoutParams(-1, -2));
    }

    private void toggle(String title, String summary, final String key, boolean def) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(14), dp(12), dp(10), dp(12));
        GradientDrawable bg = new GradientDrawable();
        bg.setCornerRadius(dp(16));
        bg.setColor(0xFF11131A);
        bg.setStroke(dp(1), 0xFF242834);
        row.setBackground(bg);

        LinearLayout labels = new LinearLayout(this);
        labels.setOrientation(LinearLayout.VERTICAL);
        TextView t = text(title, 16f, Color.WHITE, true);
        TextView s = text(summary, 12.5f, 0xFF8F97A8, false);
        s.setPadding(0, dp(3), dp(8), 0);
        labels.addView(t);
        labels.addView(s);
        row.addView(labels, new LinearLayout.LayoutParams(0, -2, 1f));

        final Switch sw = new Switch(this);
        sw.setChecked(prefs.getBoolean(key, def));
        row.addView(sw, new LinearLayout.LayoutParams(-2, -2));
        sw.setOnCheckedChangeListener((button, checked) -> prefs.edit().putBoolean(key, checked).apply());

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.bottomMargin = dp(9);
        content.addView(row, lp);
        row.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { sw.toggle(); }
        });
    }
}
