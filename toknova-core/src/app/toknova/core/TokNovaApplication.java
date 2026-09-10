package app.toknova.core;

import com.ss.android.ugc.aweme.app.host.AwemeHostApplication;

public final class TokNovaApplication extends AwemeHostApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        TokNovaCore.init(this);
    }
}
