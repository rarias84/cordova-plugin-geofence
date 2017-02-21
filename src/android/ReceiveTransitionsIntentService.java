package com.cowbell.cordova.geofence;

import android.app.Activity;
import android.app.IntentService;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingEvent;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Calendar;

public class ReceiveTransitionsIntentService extends IntentService {
    protected static final String GeofenceTransitionIntent = "com.cowbell.cordova.geofence.TRANSITION";
    public static final String GeofenceActiveQueryIntent = "com.cowbell.cordova.geofence.APP_ACTIVE_QUERY";
    protected BeepHelper beepHelper;
    protected GeoNotificationNotifier notifier;
    protected GeoNotificationStore store;

    /**
     * Sets an identifier for the service
     */
    public ReceiveTransitionsIntentService() {
        super("ReceiveTransitionsIntentService");
        beepHelper = new BeepHelper();
        store = new GeoNotificationStore(this);
        Logger.setLogger(new Logger(GeofencePlugin.TAG, this, false));
    }

    /**
     * Handles incoming intents
     *
     * @param intent
     *            The Intent sent by Location Services. This Intent is provided
     *            to Location Services (inside a PendingIntent) when you call
     *            addGeofences()
     */
    @Override
    protected void onHandleIntent(Intent intent) {
        Logger logger = Logger.getLogger();
        logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - testHandleIntent");

        // BroadcastIntent propagated when a Transition Event happens
        Intent broadcastIntent = new Intent(GeofenceTransitionIntent);

        CallbackBroadcastReceiver callback = new CallbackBroadcastReceiver(this, broadcastIntent, intent);
        sendOrderedBroadcast(broadcastIntent, null, callback, null, Activity.RESULT_OK, null, null);
    }

    /*
    *
    * */
    private class CallbackBroadcastReceiver extends BroadcastReceiver {

        private Context context = null;
        private GeoNotificationNotifier notifier;
        private Intent googleTransitionIntent;
        /*
        *  Broadcast Intent to be sent to the application.
        */
        private Intent broadcastIntent;

        public CallbackBroadcastReceiver(Context context, final Intent broadcastIntent, final Intent GoogleTransitionIntent) {
            this.context = context;
            this.broadcastIntent = broadcastIntent;
            this.googleTransitionIntent = GoogleTransitionIntent;
        }

        @Override
        public void onReceive(Context context, Intent intent) {

            Logger logger = Logger.getLogger();
            logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - broadcast callback received 2.");

            notifier = new GeoNotificationNotifier((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE), context);

            // First check for errors
            GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(this.googleTransitionIntent);

            // Is the application running?
            // We know that the application is running because the intent was received by GeofencePlugin
            // that in turn set the boolean 'HANDLED' to true.

            Bundle results = getResultExtras(true);
            boolean handled = results.getBoolean("HANDLED");

            if (geofencingEvent.hasError()) {
                // Get the error code with a static method
                int errorCode = geofencingEvent.getErrorCode();
                String error = "Location Services error: " + Integer.toString(errorCode);
                // Log the error
                logger.log(Log.ERROR, error);
                // broadcastIntent.putExtra("error", error);

            } else {
                // Get the type of transition (entry or exit)
                int transitionType = geofencingEvent.getGeofenceTransition();
                if ((transitionType == Geofence.GEOFENCE_TRANSITION_ENTER)
                        || (transitionType == Geofence.GEOFENCE_TRANSITION_EXIT)) {
                    logger.log(Log.DEBUG, "Geofence transition detected");
                    List<Geofence> triggerList = geofencingEvent.getTriggeringGeofences();
                    List<GeoNotification> geoNotifications = new ArrayList<GeoNotification>();

                    if (handled) {
                        boolean showNotification = false;
                        // The application is up and running so we want to notify directly into the
                        // webview

                        for (Geofence fence : triggerList) {
                            String fenceId = fence.getRequestId();
                            GeoNotification geoNotification = store
                                    .getGeoNotification(fenceId);

                            showNotification = validateTimeInterval(geoNotification);
                            
                            if (geoNotification != null) {
                                geoNotification.openedFromNotification = false;
                                geoNotification.transitionType = transitionType;
                                geoNotifications.add(geoNotification);
                            }
                        }

                        if (geoNotifications.size() > 0 && showNotification) {
                            broadcastIntent.putExtra("transitionData", Gson.get().toJson(geoNotifications));
                            GeofencePlugin.onTransitionReceived(geoNotifications);
                        }

                    } else {
                        for (Geofence fence : triggerList) {
                            String fenceId = fence.getRequestId();
                            GeoNotification geoNotification = store
                                    .getGeoNotification(fenceId);

                            if (geoNotification != null && validateTimeInterval(geoNotification)) {
                                geoNotification.openedFromNotification = true;
                                geoNotification.transitionType = transitionType;
                                geoNotifications.add(geoNotification);

                                if (geoNotification.notification != null) {
                                    notifier.notify(geoNotification);
                                }
                            }
                        }
                    }
                } else {
                    String error = "Geofence transition error: " + transitionType;
                    logger.log(Log.ERROR, error);
                    broadcastIntent.putExtra("error", error);
                }
            }
            // TODO(jppg) sendBroadcast
            // Decide if we're gong to have a different name for the broadcast intent
            // in order to differentiate the intent with callback to know if the application is running
            // and the intent that is broadcast by the plugin for "native" usage
            //sendBroadcast(broadcastIntent);

        }
    }

    /**
     * Method to check if there are configurations to show the Notification. If so, validate if the date is inside of range
     * @param geoNotification
     * @return
     */
    private boolean validateTimeInterval(GeoNotification geoNotification){
        final Logger logger = Logger.getLogger();
        boolean showNotification = false;
        //Validate if the Geofence has an interval of time to show notification
        String timestampStart = geoNotification.notification.dateStart;
        String timestampEnd = geoNotification.notification.dateEnd;
        boolean happensOnce = geoNotification.notification.happensOnce;
        boolean notificationShowed = geoNotification.notification.notificationShowed;

        Date timestampNotificationShowed = geoNotification.notification.dateNotificationShowed;
        int secondsBetweenNotifications = geoNotification.notification.secondsBetweenNotifications;

//        logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Geofence transition detected - happensOnce - "+happensOnce);
//        logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Geofence transition detected - notificationShowed - "+notificationShowed);
//        logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Geofence transition detected - timestampNotificationShowed - "+timestampNotificationShowed);
//        logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Geofence transition detected - secondsBetweenNotifications - "+secondsBetweenNotifications);

        if(notificationShowed && happensOnce){
            showNotification = false;
            return showNotification;
        }

        Date dateNow = new Date();
        if((timestampStart == null || timestampStart == "") && (timestampEnd == null || timestampEnd == "")) {
            if (secondsBetweenNotifications == 0) {
                showNotification = true;
            }else{
                if (timestampNotificationShowed == null ){
                    showNotification = true;
                }else{
//                    logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Vamo a calcular ");
                    Calendar calendar = Calendar.getInstance();
                    calendar.setTime(timestampNotificationShowed);
                    calendar.add(Calendar.SECOND, secondsBetweenNotifications);
//                    logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - Now "+dateNow);
//                    logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - timestampNotificationShowed "+timestampNotificationShowed);
//                    logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - calendar.getTime() o sea +120 segundos "+calendar.getTime());
                    showNotification = !dateIsBetweenIntervalDate(dateNow, timestampNotificationShowed, calendar.getTime());
//                    logger.log(Log.DEBUG, "ReceiveTransitionsIntentService - showNotification  "+showNotification);
                }
                if (showNotification){
                    geoNotification.notification.dateNotificationShowed = dateNow;
                    store.setGeoNotification(geoNotification);
                }
            }
        } else {
            DateFormat formatter ;
            Date dateStart = null;
            Date dateEnd = null;
            //formatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
            formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");
            try {
                dateStart = formatter.parse(timestampStart);
            } catch (ParseException e) {
                logger.log(Log.ERROR, e.toString());
            }

            try {
                dateEnd = formatter.parse(timestampEnd);
            } catch (ParseException e) {
                logger.log(Log.ERROR, e.toString());
            }

            if (dateStart.equals(dateEnd) || dateStart.after(dateEnd)) {
                dateEnd = new Date();
            }

            showNotification = dateIsBetweenIntervalDate(dateNow, dateStart, dateEnd);

            if (timestampNotificationShowed != null ){
                Calendar calendar = Calendar.getInstance();
                calendar.setTime(timestampNotificationShowed);
                calendar.add(Calendar.SECOND, secondsBetweenNotifications);
                showNotification = showNotification ? !dateIsBetweenIntervalDate(dateNow, timestampNotificationShowed, calendar.getTime()) : showNotification;
            }

            if(showNotification && !notificationShowed && happensOnce) {
                geoNotification.notification.notificationShowed = true;
                geoNotification.notification.dateNotificationShowed = dateNow;
                store.setGeoNotification(geoNotification);

                List<String> ids = new ArrayList<String>();
                ids.add(geoNotification.id);
                RemoveGeofenceCommand cmd = new RemoveGeofenceCommand(getApplicationContext(), ids);
                cmd.addListener(new IGoogleServiceCommandListener() {
                    @Override
                    public void onCommandExecuted(boolean withSuccess) {
                        logger.log(Log.DEBUG, "Geofence Removed");
                    }
                });
                GoogleServiceCommandExecutor googleServiceCommandExecutor = new GoogleServiceCommandExecutor();
                googleServiceCommandExecutor.QueueToExecute(cmd);
            }
        }
        //End of changes
        return showNotification;
    }

    private boolean dateIsBetweenIntervalDate(Date date, Date startDate, Date endDate) {
        return date.after(startDate) && date.before(endDate);
    }

}
