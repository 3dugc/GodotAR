package org.godotengine.plugin.android.godotarcore;

import android.app.Activity;
import android.util.Log;
import android.view.View;

import com.google.ar.core.ArCoreApk;
import com.google.ar.core.Config;
import com.google.ar.core.Session;
import com.google.ar.core.exceptions.CameraNotAvailableException;
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Arrays;
import java.util.List;

public class GodotARCorePlugin extends GodotPlugin {
    private static final String TAG = "GodotARCore";
    private static final String PLUGIN_NAME = "GodotARCore";

    private Activity activity;
    private Session session;
    private boolean running = false;
    private boolean sessionRequested = false;
    private boolean userRequestedInstall = true;
    private String lastAvailability = "UNKNOWN";
    private String lastInstallStatus = "UNKNOWN";
    private String lastError = "";

    public GodotARCorePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public View onMainCreate(Activity activity) {
        this.activity = activity;
        return null;
    }

    @Override
    public void onMainPause() {
        pauseSession();
    }

    @Override
    public void onMainResume() {
        if (sessionRequested) {
            resumeSession();
        }
    }

    @Override
    public void onMainDestroy() {
        stop_session();
    }

    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    @Override
    public List<String> getPluginMethods() {
        return Arrays.asList(
                "check_availability",
                "is_supported",
                "install",
                "request_install",
                "request_arcore_install",
                "initialize",
                "start_session",
                "start",
                "resume",
                "pause",
                "stop_session",
                "stop",
                "is_running",
                "get_tracking_status",
                "get_not_tracking_reason",
                "get_capabilities",
                "get_last_error"
        );
    }

    @UsedByGodot
    public Dictionary check_availability() {
        Dictionary report = new Dictionary();
        Activity currentActivity = activity;
        boolean supported = false;

        if (currentActivity == null) {
            lastAvailability = "UNKNOWN_NO_ACTIVITY";
            lastError = "Android Activity is not available yet.";
        } else {
            ArCoreApk.Availability availability = ArCoreApk.getInstance().checkAvailability(currentActivity);
            lastAvailability = availability.name();
            supported = availability.isSupported();
            if (!supported && availability == ArCoreApk.Availability.UNKNOWN_CHECKING) {
                lastError = "ARCore availability is still checking.";
            } else if (!supported) {
                lastError = "ARCore availability is " + lastAvailability + ".";
            } else {
                lastError = "";
            }
        }

        report.put("supported", supported);
        report.put("availability", supported ? "Supported" : "Unsupported");
        report.put("arcore_availability", lastAvailability);
        report.put("arcore_install_status", lastInstallStatus);
        report.put("native_plugin", true);
        report.put("runtime", "ARCore");
        report.put("arcore_supported", supported);
        report.put("arcore_running", running);
        report.put("last_error", lastError);
        return report;
    }

    @UsedByGodot
    public boolean is_supported() {
        return Boolean.TRUE.equals(check_availability().get("supported"));
    }

    @UsedByGodot
    public boolean install() {
        return request_arcore_install();
    }

    @UsedByGodot
    public boolean request_install() {
        return request_arcore_install();
    }

    @UsedByGodot
    public boolean request_arcore_install() {
        Activity currentActivity = activity;
        if (currentActivity == null) {
            lastError = "Android Activity is not available for ARCore install request.";
            return false;
        }

        try {
            ArCoreApk.InstallStatus status = ArCoreApk.getInstance().requestInstall(currentActivity, true);
            lastInstallStatus = status.name();
            if (status == ArCoreApk.InstallStatus.INSTALLED) {
                userRequestedInstall = false;
                lastError = "";
                return true;
            }
            userRequestedInstall = false;
            lastError = "ARCore install was requested. Run the app again after installation completes.";
            return false;
        } catch (UnavailableUserDeclinedInstallationException error) {
            lastInstallStatus = "USER_DECLINED";
            lastError = error.getClass().getSimpleName() + ": " + error.getMessage();
            Log.w(TAG, lastError, error);
            return false;
        } catch (Exception error) {
            lastInstallStatus = "ERROR";
            lastError = error.getClass().getSimpleName() + ": " + error.getMessage();
            Log.e(TAG, lastError, error);
            return false;
        }
    }

    @UsedByGodot
    public boolean initialize() {
        return ensureSession();
    }

    @UsedByGodot
    public boolean start_session() {
        if (!ensureSession()) {
            return false;
        }
        sessionRequested = true;
        return resumeSession();
    }

    @UsedByGodot
    public boolean start() {
        return start_session();
    }

    @UsedByGodot
    public boolean resume() {
        return resumeSession();
    }

    @UsedByGodot
    public void pause() {
        sessionRequested = false;
        pauseSession();
    }

    @UsedByGodot
    public void stop_session() {
        sessionRequested = false;
        if (session != null) {
            session.pause();
            session.close();
            session = null;
        }
        running = false;
    }

    @UsedByGodot
    public void stop() {
        stop_session();
    }

    @UsedByGodot
    public boolean is_running() {
        return running;
    }

    @UsedByGodot
    public String get_tracking_status() {
        return running ? "unknown_tracking" : "not_tracking";
    }

    @UsedByGodot
    public String get_not_tracking_reason() {
        if (running) {
            return "waiting_for_frame";
        }
        if (!lastError.isEmpty()) {
            return "unsupported";
        }
        return "not_running";
    }

    @UsedByGodot
    public Dictionary get_capabilities() {
        Dictionary capabilities = new Dictionary();
        boolean supported = is_supported();

        capabilities.put("runtime", "ARCore");
        capabilities.put("native_plugin", true);
        capabilities.put("arcore_supported", supported);
        capabilities.put("arcore_running", running);
        capabilities.put("arcore_availability", lastAvailability);
        capabilities.put("arcore_install_status", lastInstallStatus);
        capabilities.put("session", supported);
        capabilities.put("tracking", running);
        capabilities.put("camera_background", false);
        capabilities.put("passthrough", false);
        capabilities.put("raycast", false);
        capabilities.put("plane_detection", false);
        capabilities.put("anchors", false);
        capabilities.put("persistent_anchors", false);
        capabilities.put("light_estimation", false);
        capabilities.put("depth", false);
        capabilities.put("image_tracking", false);
        capabilities.put("ar_product_path", supported);
        capabilities.put("last_error", lastError);
        return capabilities;
    }

    @UsedByGodot
    public String get_last_error() {
        return lastError;
    }

    private boolean ensureSession() {
        Activity currentActivity = activity;
        if (currentActivity == null) {
            lastError = "Android Activity is not available for ARCore session creation.";
            return false;
        }

        if (session != null) {
            return true;
        }

        try {
            ArCoreApk.InstallStatus status = ArCoreApk.getInstance().requestInstall(currentActivity, userRequestedInstall);
            lastInstallStatus = status.name();
            if (status == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                userRequestedInstall = false;
                lastError = "ARCore install/update requested. Session will be created after Activity resumes.";
                return false;
            }

            session = new Session(currentActivity);
            Config config = new Config(session);
            config.setPlaneFindingMode(Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL);
            session.configure(config);
            userRequestedInstall = false;
            lastError = "";
            return true;
        } catch (Exception error) {
            lastError = error.getClass().getSimpleName() + ": " + error.getMessage();
            Log.e(TAG, lastError, error);
            return false;
        }
    }

    private boolean resumeSession() {
        if (session == null) {
            return ensureSession() && resumeSession();
        }

        try {
            session.resume();
            running = true;
            lastError = "";
            return true;
        } catch (CameraNotAvailableException error) {
            running = false;
            lastError = error.getClass().getSimpleName() + ": " + error.getMessage();
            Log.e(TAG, lastError, error);
            return false;
        }
    }

    private void pauseSession() {
        if (session != null) {
            session.pause();
        }
        running = false;
    }
}
