package app.toknova.core;

import android.app.Activity;
import android.app.Application;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.widget.FrameLayout;
import android.widget.TextView;

public final class TokNovaCore {
    public static final String VERSION = "0.1.0";
    public static final String PREFS = "toknova_prefs";
    private static Application app;

    private TokNovaCore() {}

    public static void init(Application application) {
        if (app != null) return;
        app = application;
        application.registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
            @Override public void onActivityCreated(Activity activity, Bundle state) {}
            @Override public void onActivityStarted(Activity activity) {}
            @Override public void onActivityPaused(Activity activity) {}
            @Override public void onActivityStopped(Activity activity) {}
            @Override public void onActivitySaveInstanceState(Activity activity, Bundle state) {}
            @Override public void onActivityDestroyed(Activity activity) {}

            @Override
            public void onActivityResumed(final Activity activity) {
                if (activity.getClass().getName().equals("com.ss.android.ugc.aweme.main.MainActivity")) {
                    activity.getWindow().getDecorView().postDelayed(new Runnable() {
                        @Override public void run() {
                            installSettingsButton(activity);
                            installViewFilter(activity);
                        }
                    }, 900L);
                }
            }
        });
    }

    public static SharedPreferences prefs() {
        return app.getSharedPreferences(PREFS, 0);
    }

    private static int dp(Activity a, int value) {
        return (int) (value * a.getResources().getDisplayMetrics().density + 0.5f);
    }

    private static void installSettingsButton(final Activity activity) {
        SharedPreferences p = prefs();
        if (!p.getBoolean("core_button", true)) return;
        ViewGroup root = (ViewGroup) activity.getWindow().getDecorView();
        if (root.findViewWithTag("toknova_settings_button") != null) return;

        TextView button = new TextView(activity);
        button.setTag("toknova_settings_button");
        button.setText("⚙");
        button.setTextColor(Color.WHITE);
        button.setTextSize(22f);
        button.setGravity(Gravity.CENTER);
        button.setContentDescription("TokNova Settings");

        GradientDrawable bg = new GradientDrawable();
        bg.setShape(GradientDrawable.OVAL);
        bg.setColor(0xD91A1C24);
        bg.setStroke(dp(activity, 1), 0xFF42E8E0);
        button.setBackground(bg);
        button.setElevation(dp(activity, 8));

        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(dp(activity, 46), dp(activity, 46));
        lp.gravity = Gravity.TOP | Gravity.END;
        lp.topMargin = dp(activity, 105);
        lp.rightMargin = dp(activity, 12);
        root.addView(button, lp);

        button.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                Intent intent = new Intent(activity, SettingsActivity.class);
                activity.startActivity(intent);
            }
        });
    }

    private static void installViewFilter(final Activity activity) {
        final View root = activity.getWindow().getDecorView();
        if (root.getTag(0x7f0b0001) != null) return;
        try { root.setTag(0x7f0b0001, Boolean.TRUE); } catch (Throwable ignored) { return; }
        root.getViewTreeObserver().addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override public void onGlobalLayout() {
                try { applyFilters(root); } catch (Throwable ignored) {}
            }
        });
    }

    private static void applyFilters(View view) {
        SharedPreferences p = prefs();
        CharSequence text = null;
        if (view instanceof TextView) text = ((TextView) view).getText();
        CharSequence desc = view.getContentDescription();

        if (text != null) {
            String s = text.toString().trim();
            if (p.getBoolean("hide_live", false) && (s.equalsIgnoreCase("LIVE") || s.equalsIgnoreCase("Live"))) {
                view.setVisibility(View.GONE);
            }
            if (p.getBoolean("hide_shop", false) && (s.equalsIgnoreCase("Shop") || s.equalsIgnoreCase("TikTok Shop") || s.equalsIgnoreCase("Магазин"))) {
                view.setVisibility(View.GONE);
            }
            if (p.getBoolean("hide_friends", false) && (s.equalsIgnoreCase("Friends") || s.equalsIgnoreCase("Друзья"))) {
                view.setVisibility(View.GONE);
            }
        }

        if (p.getBoolean("focus_mode", false) && desc != null) {
            String d = desc.toString().toLowerCase();
            if (d.contains("like") || d.contains("comment") || d.contains("share") || d.contains("repost")) {
                view.setVisibility(View.GONE);
            }
        }

        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) applyFilters(group.getChildAt(i));
        }
    }
}
