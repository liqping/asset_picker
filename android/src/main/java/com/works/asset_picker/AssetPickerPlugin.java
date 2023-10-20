package com.works.asset_picker;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.media.MediaMetadataRetriever;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;


import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

import java.io.*;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import static android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC;
import static android.media.ThumbnailUtils.OPTIONS_RECYCLE_INPUT;

/**
 * AssetPickerPlugin
 */
public class AssetPickerPlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener {

    //  private final MethodChannel channel;

    private MethodChannel channel;

    private  Activity activity;
    private  Context context;
    //  private final BinaryMessenger messenger;
    private MethodChannel.Result pendingResult;
    private MethodCall methodCall;

    private Map<String,Object> permissionRequest;

    private static final int REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL = 2001;
    private static final int REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION = 2002;

    //创建基本线程池
    final ThreadPoolExecutor threadPoolExecutor = new ThreadPoolExecutor(
            5, 15, 2,
            TimeUnit.SECONDS,
            new LinkedBlockingQueue<Runnable>(30), new PluginRunnable.DiscardOldestPolicy());

    //创建基本线程池
    final ThreadPoolExecutor threadPoolExecutorCache = new ThreadPoolExecutor(
            1, 4, 1,
            TimeUnit.SECONDS,
            new LinkedBlockingQueue<Runnable>(10), new ThreadPoolExecutor.DiscardOldestPolicy());

    //创建基本线程池
    final ThreadPoolExecutor threadPoolExecutorFileSave = new ThreadPoolExecutor(
            1, 3, 0,
            TimeUnit.MILLISECONDS,
            new LinkedBlockingQueue<>());


    /**
     * Plugin registration.
     */
    @SuppressWarnings("deprecation")
    public static void registerWith(PluginRegistry.Registrar registrar) {
        AssetPickerPlugin instance = new AssetPickerPlugin();
        instance.channel = new MethodChannel(registrar.messenger(), "asset_picker");
        instance.activity = registrar.activity();
        instance.context = registrar.context();
        registrar.addRequestPermissionsResultListener(instance);
        instance.channel.setMethodCallHandler(instance);
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "asset_picker");
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        permissionRequest = new HashMap<>();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        context = null;
        channel = null;
        permissionRequest = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }


    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }


    //    private AssetPickerPlugin(Activity activity, Context context) {
//        this.activity = activity;
//        this.context = context;
//        permissionRequest = new HashMap<>();
////    this.channel = channel;
////    this.messenger = messenger;
//    }

    @Override
    public void onMethodCall(MethodCall call, final MethodChannel.Result result) {

        this.methodCall = call;
        this.pendingResult = result;

        if (call.method.equals("getAllAssetCatalog")) {
            if (requestPermission(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL)) {
                getAllAssetCatalog();
            }
        } else if (call.method.equals("getAssetsFromCatalog")) {

            Map arguments = (Map) this.methodCall.arguments;

            String foldPath = (String) arguments.get("identifier");
            if (foldPath.equals("all_identifier"))  //全部照片
            {
                if (requestPermission(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION)) {
                    getAssetsFromCatalog();
                }
            } else {
                result.error("-1", "参数错误!", null);
                clearMethodCallAndResult();
            }
        } else if (call.method.equals("getFileExternalContentUri")) {
            clearMethodCallAndResult();
            final Uri uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
            if(uri == null){
                result.error("-1", "获取URI失败!", null);
            }
            else{
                result.success(uri.toString());
            }

        }else if (call.method.equals("requestImageThumbnail")) {
            clearMethodCallAndResult();
            final Map arguments = (Map) call.arguments;

            final String path = (String) arguments.get("identifier");

            final int width = ((int) arguments.get("width"));
            final int height = ((int) arguments.get("height"));
            final int quality = ((int) arguments.get("quality"));

            final boolean needCache = ((boolean) arguments.get("needCache"));

            final boolean isVideo = ((boolean)arguments.get("isVideo"));
            try {

                threadPoolExecutor.execute(new PluginRunnable(result) {
                    @Override
                    public void run() {
                        try {
                            // get a reference to the activity if it is still there

                            Uri uri = MediaStore.Files.getContentUri("external");
                            Object filed = arguments.get("fileId");
                            final long fileId = filed != null? Long.parseLong(String.valueOf(filed)): 0;
                            final Uri fileUri =  ContentUris.withAppendedId(uri,fileId);

                            if(isVideo) {

                                Bitmap thumbBitmap;
                                if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q){
                                    MediaMetadataRetriever media = new MediaMetadataRetriever();
                                    media.setDataSource(activity,fileUri);
                                    thumbBitmap = media.getScaledFrameAtTime(-1,OPTION_CLOSEST_SYNC,width,height);

                                }
                                else{
                                    thumbBitmap = ThumbnailUtils.createVideoThumbnail(path, MediaStore.Images.Thumbnails.MINI_KIND);
                                }

                                if(thumbBitmap == null){
                                    result.error("-5", "读取文件错误", null);
                                    return;
                                }

                                ByteArrayOutputStream bitmapStream = new ByteArrayOutputStream();
                                thumbBitmap.compress(Bitmap.CompressFormat.JPEG, quality, bitmapStream);
                                final byte[] byteArray = bitmapStream.toByteArray();
                                if(needCache){
                                    final String thumbPath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(path + "_" + width + "_" + height);
                                    final FileOutputStream fos = new FileOutputStream(thumbPath);
                                    bitmapStream.writeTo(fos);
                                    fos.flush();
                                    fos.close();
                                }

                                thumbBitmap.recycle();
                                bitmapStream.close();
                                result.success(byteArray);
                                return;
                            }

                            int orientation = getOrientation(context, path);


                            InputStream inStream = activity.getContentResolver().openInputStream(fileUri);
                            final byte[] bytes = readStream(inStream);
                            inStream.close();
                            BitmapFactory.Options options = new BitmapFactory.Options();
                            options.inJustDecodeBounds = true;

                            BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);

                            options.inSampleSize = calculateInSampleSize(options,width,height);

                            options.inJustDecodeBounds = false;

                            Bitmap sourceBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);

                            if (sourceBitmap == null) {
                                result.error("-5", "读取文件错误", null);
                                return;
                            }

                            Matrix matrix = null;
                            if (orientation > 0){
                                matrix = new Matrix();
                                matrix.setRotate(orientation);
                            }
                            final int picWidth = sourceBitmap.getWidth();
                            final int picHeight = sourceBitmap.getHeight();
                            final float wRatio =  width / (float)picWidth;
                            final float hRatio = height / (float)picHeight;
                            final float scale = Math.min(wRatio,hRatio);
                            if(matrix == null){
                                matrix = new Matrix();
                                matrix.setScale(scale,scale);
                            }
                            else{
                                matrix.postScale(scale,scale);
                            }

                            final Bitmap temp = Bitmap.createBitmap(sourceBitmap,0,0,sourceBitmap.getWidth(),sourceBitmap.getHeight(),matrix,true);
                            if(temp != sourceBitmap){
                                sourceBitmap.recycle();
                                sourceBitmap = temp;
                            }

                            ByteArrayOutputStream bitmapStream = new ByteArrayOutputStream();
                            sourceBitmap.compress(Bitmap.CompressFormat.JPEG, quality, bitmapStream);
                            final byte[] byteArray = bitmapStream.toByteArray();
                            result.success(byteArray);
                            sourceBitmap.recycle();
                            if(needCache){
                                final String thumbPath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(path + "_" + width + "_" + height);
                                threadPoolExecutorFileSave.execute(() -> {
                                    FileOutputStream fs = null;
                                    try{
                                        fs = new FileOutputStream(thumbPath);
                                        bitmapStream.writeTo(fs);
                                        fs.flush();
                                        fs.close();
                                        fs = null;
                                        bitmapStream.close();

                                    }catch (Exception e){
                                        if(fs != null){
                                            try {
                                                bitmapStream.close();
                                            } catch (IOException ex) {
                                                ex.printStackTrace();
                                            }
                                        }
                                        e.printStackTrace();
                                    }
                                });
                            }else{
                                bitmapStream.close();
                            }

                        } catch (Exception e) {
                            e.printStackTrace();
                            result.error("-5", "读取文件错误", null);
                        }
                    }
                });
            } catch (Exception ex) {
                ex.printStackTrace();
                result.error("-5", "读取文件错误", null);

            }

        } else if (call.method.equals("requestImageOriginal")) {

            clearMethodCallAndResult();
            final Map arguments = (Map) call.arguments;

            final String path = (String) arguments.get("identifier");

            final int quality = ((int) arguments.get("quality"));

            final boolean isVideo = ((boolean)arguments.get("isVideo"));

            if(isVideo){
                try {
                    threadPoolExecutor.execute(new PluginRunnable(result) {
                        @Override
                        public void run() {
                            try {

                                final String thumbPath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(path + "_" + 0 + "_" + 0);
                                File thumbFile = AssetPickerPlugin.fileIsExists(thumbPath);
                                if (thumbFile != null) {
                                    final Uri thumbUri = Uri.fromFile(thumbFile);
                                    final InputStream is = activity.getContentResolver().openInputStream(thumbUri);
                                    final byte[] thumbByte = AssetPickerPlugin.inputStreamTOByte(is);
                                    is.close();
                                    result.success(thumbByte);
                                    return;
                                }

                                MediaMetadataRetriever media = new MediaMetadataRetriever();
                                Object filed = arguments.get("fileId");
                                final long fileId = filed != null? Long.parseLong(String.valueOf(filed)): 0;
                                Uri uri = MediaStore.Files.getContentUri("external");
                                final Uri fileUri =  ContentUris.withAppendedId(uri,fileId);

                                media.setDataSource(activity,fileUri);

                                ByteArrayOutputStream bitmapStream = new ByteArrayOutputStream();
                                Bitmap ThumbBitmap = media.getFrameAtTime();
                                ThumbBitmap.compress(Bitmap.CompressFormat.JPEG, quality, bitmapStream);
                                final byte[] byteArray = bitmapStream.toByteArray();

                                result.success(byteArray);

                                final FileOutputStream fos = new FileOutputStream(thumbPath);
                                bitmapStream.writeTo(fos);

                                fos.flush();
                                fos.close();

                                ThumbBitmap.recycle();
                                bitmapStream.close();

                            } catch (IOException e) {
                                e.printStackTrace();
                                result.error("-5", "读取文件错误", null);
                            }

                        }
                    });
                }
                catch (Exception ex) {
                    ex.printStackTrace();
                    result.error("-5", "读取文件错误", null);
                }
            }
            else
            {
                try {
                    threadPoolExecutor.execute(new PluginRunnable(result) {
                        @Override
                        public void run() {
                            try {

                                Object filed = arguments.get("fileId");
                                final long fileId = filed != null? Long.parseLong(String.valueOf(filed)): 0;
                                Uri uri = MediaStore.Files.getContentUri("external");

                                final Uri fileUri =  ContentUris.withAppendedId(uri,fileId);

                                final InputStream inStream = activity.getContentResolver().openInputStream(fileUri);

                                final byte[] bytes = readStream(inStream);

                                final int maxWidth = arguments.containsKey("width") ?  ((int) arguments.get("width")) : -1;
                                final int maxHeight = arguments.containsKey("height") ?  ((int) arguments.get("height")) : -1;

                                if(maxWidth <= 0 && maxHeight <= 0){
                                    result.success(bytes);
                                    return;
                                }

                                BitmapFactory.Options options = new BitmapFactory.Options();
                                options.inJustDecodeBounds = true;

                                BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);
                                final int originHeight = options.outHeight;
                                final int originWidth = options.outWidth;

                                if(originWidth <= maxWidth && originHeight <= maxHeight){
                                    result.success(bytes);
                                    return;
                                }

                                options.inSampleSize = calculateInSampleSize(options,maxWidth,maxHeight);
                                options.inJustDecodeBounds = false;
                                Bitmap sourceBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
                                if (sourceBitmap == null) {
                                    result.error("-5", "读取文件错误", null);
                                    return;
                                }

                                int orientation = getOrientation(context, path);

                                Matrix matrix = null;
                                if (orientation > 0){
                                    matrix = new Matrix();
                                    matrix.setRotate(orientation);
                                }
                                final int picWidth = sourceBitmap.getWidth();
                                final int picHeight = sourceBitmap.getHeight();
                                if(picWidth > maxWidth || picHeight > maxHeight){
                                    final float wRatio = maxWidth > 0 ? maxWidth / (float)picWidth : 1.f;
                                    final float hRatio = maxHeight > 0 ? maxHeight / (float)picHeight : 1.f;
                                    final float scale = Math.min(wRatio,hRatio);
                                    if(matrix == null){
                                        matrix = new Matrix();
                                        matrix.setScale(scale,scale);
                                    }
                                    else{
                                        matrix.postScale(scale,scale);
                                    }
                                }
                                if(matrix != null){
                                    final Bitmap temp = Bitmap.createBitmap(sourceBitmap,0,0,sourceBitmap.getWidth(),sourceBitmap.getHeight(),matrix,true);
                                    if(temp != sourceBitmap){
                                        sourceBitmap.recycle();
                                        sourceBitmap = temp;
                                    }
                                }
                                ByteArrayOutputStream bitmapStream = new ByteArrayOutputStream();
                                sourceBitmap.compress(Bitmap.CompressFormat.JPEG, quality, bitmapStream);

                                final byte[] byteArray = bitmapStream.toByteArray();

                                result.success(byteArray);

                                sourceBitmap.recycle();
                                bitmapStream.close();
                            } catch (Exception e) {
                                e.printStackTrace();
                                result.error("-5", "读取文件错误", null);
                            }
                        }
                    });
                } catch (Exception ex) {
                    ex.printStackTrace();
                    result.error("-5", "读取文件错误", null);
                }
            }


        }
        else if (call.method.equals("rawDataToJpgFile")) {
            clearMethodCallAndResult();
            final Map arguments = (Map) call.arguments;
            final int thumbWidth = (int) arguments.get("thumbWidth");
            final int thumbHeight = (int) arguments.get("thumbHeight");


            if(thumbWidth <= 0 || thumbHeight <= 0){
                result.success(null);
                return;
            }

            final String fileName = (String) arguments.get("fileName");
            final int quality = (int) arguments.get("quality");
            final int width = (int) arguments.get("width");
            final int height = (int) arguments.get("height");

            final int[] rawData = ((int[]) arguments.get("rawData"));
            convertByteToColor(rawData);
            final Bitmap bitmap = Bitmap.createBitmap(rawData,width, height, Bitmap.Config.ARGB_8888);

            final String filePath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(fileName) + ".jpg";

            final File file=new File(filePath);

            threadPoolExecutor.execute(new PluginRunnable(result) {
                        @Override
                        public void run() {
                            try {
                                int tW = thumbWidth;
                                int tH = thumbHeight;


                                FileOutputStream fos = new FileOutputStream(file);
                                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, fos);

                                final Map<String, String> pathInfo = new HashMap<>();
                                pathInfo.put("path",filePath);

                                double ratio = (double) width/(double)height;

                                if((double)tW/(double)tH > ratio){
                                    tW = (int)(tH * ratio);
                                }
                                else{
                                    tH = (int)(tW / ratio);
                                }
                                Bitmap thumbBitmap = ThumbnailUtils.extractThumbnail(bitmap, tW, tH, OPTIONS_RECYCLE_INPUT);
                                final String thumbFilePath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(fileName) + "_.jpg";
                                FileOutputStream fos1 = new FileOutputStream(new File(thumbFilePath));

                                thumbBitmap.compress(Bitmap.CompressFormat.JPEG, 100, fos1);

                                pathInfo.put("thumb",thumbFilePath);

                                thumbBitmap.recycle();
                                fos1.flush();
                                fos1.close();
                                fos.flush();
                                fos.close();
                                result.success(pathInfo);

                            } catch (Exception ex) {
                                ex.printStackTrace();
                                result.error("-2", "save failure", null);
                            }
                            finally {
                                bitmap.recycle();
                            }
                        }
                    }
            );
        }
//        else if (call.method.equals("rawDataToPngFile")) {
//            clearMethodCallAndResult();
//            final Map arguments = (Map) call.arguments;
//            final String fileName = (String) arguments.get("fileName");
//            final int width = (int) arguments.get("width");
//            final int height = (int) arguments.get("height");
//            final int thumbWidth = (int) arguments.get("thumbWidth");
//            final int thumbHeight = (int) arguments.get("thumbHeight");
//            final int[] rawData = ((int[]) arguments.get("rawData"));
//            convertByteToColor(rawData);
//            final Bitmap bitmap = Bitmap.createBitmap(rawData,width, height, Bitmap.Config.ARGB_8888);
//
//            final String filePath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(fileName) + ".png";
//
//            final File file=new File(filePath);
//
//            threadPoolExecutor.execute(new Runnable() {
//                @Override
//                public void run() {
//                    try {
//
//                        int tW = thumbWidth;
//                        int tH = thumbHeight;
//
//                        FileOutputStream fos = new FileOutputStream(file);
//                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos);
//
//                        final Map<String, String> pathInfo = new HashMap<>();
//                        pathInfo.put("path",filePath);
//                        if(tW <= 0 || tH <= 0){
//
//                            activity.runOnUiThread(new Runnable() {
//                                @Override
//                                public void run() {
//                                    result.success(pathInfo);
//                                }
//                            });
//                        }
//                        else{
//                            double ratio = (double) width/(double)height;
//                                tW = (int)(tH * ratio);
//                            }
//                            else{
//                                tH = (int)(tW / ratio);
//                            }
//
//                            if((double)tW/(double)tH > ratio){
//                            Bitmap thumbBitmap = ThumbnailUtils.extractThumbnail(bitmap, tW, tH, OPTIONS_RECYCLE_INPUT);
//                            final String thumbFilePath = getCachePath() + "/" + AssetPickerPlugin.encryptToMd5(fileName) + "_.png";
//                            FileOutputStream fos1 = new FileOutputStream(new File(thumbFilePath));
//
//                            thumbBitmap.compress(Bitmap.CompressFormat.PNG, 100, fos1);
//
//                            pathInfo.put("thumb",thumbFilePath);
//                            activity.runOnUiThread(new Runnable() {
//                                @Override
//                                public void run() {
//                                    result.success(pathInfo);
//                                }
//                            });
//
//                            thumbBitmap.recycle();
//                            fos1.flush();
//                            fos1.close();
//                        }
//
//                        fos.flush();
//                        fos.close();
//
//                    } catch (Exception ex) {
//                        ex.printStackTrace();
//                        activity.runOnUiThread(new Runnable() {
//                            @Override
//                            public void run() {
//                                result.error("-2", "save failure", null);
//                            }
//                        });
//                    }
//                    finally {
//                        bitmap.recycle();
//                    }
//                }
//            });
//
//        }
        else {
            result.notImplemented();
            clearMethodCallAndResult();
        }
    }


    //判断文件是否存在
    static public File fileIsExists(String strFile) {
        try {
            File file = new File(strFile);
            if (file.exists()) {
                return file;
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    public static String encryptToMd5(String str) {
        String hexStr = "";
        try {
            byte[] bytes = MessageDigest.getInstance("MD5").digest(str.getBytes("UTF-8"));
            for (byte b : bytes) {
                String temp = Integer.toHexString(b & 0xff);
                if (temp.length() == 1) {
                    temp = "0" + temp;
                }
                hexStr += temp;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return hexStr;
    }

    String getCachePath() {
        return activity.getDir("flutter", Context.MODE_PRIVATE).getPath() + "/pickasset/imagecache";
    }

    /**
     * 将InputStream转换成byte数组
     *
     * @param in InputStream
     * @return byte[]
     * @throws IOException
     */
    public static byte[] inputStreamTOByte(InputStream in) throws IOException {

        ByteArrayOutputStream outStream = new ByteArrayOutputStream();
        byte[] data = new byte[4096];
        int count = -1;
        while ((count = in.read(data, 0, 4096)) != -1)
            outStream.write(data, 0, count);
        data = outStream.toByteArray();
        outStream.close();
        return data;
    }


    /*
     * 将RGBA数组转化为ARGB像素数组
     */
    public static void convertByteToColor(int[] data){
        if(data != null) {
            for (int i = 0; i < data.length; ++i) {
                int color = data[i];
                data[i] = (color & 0xFF000000) | (color >> 16 & 0x000000FF) | (color & 0x0000FF00) | (color << 16 & 0x00FF0000);
            }
        }
    }

    public static int calculateInSampleSize(
            BitmapFactory.Options options, int reqWidth, int reqHeight) {
        // Raw height and width of image
        if(reqWidth <= 0 && reqHeight <=0 ){
            return  1;
        }

        int inSampleSize = 1;

        if(reqWidth <= 0){
            // Raw height and width of image
            final int height = options.outHeight;
            if (height > reqHeight) {

                final int halfHeight = height / 2;

                // Calculate the largest inSampleSize value that is a power of 2 and keeps both
                // height and width larger than the requested height and width.
                while ((halfHeight / inSampleSize) >= reqHeight) {
                    inSampleSize *= 2;
                }
            }
        }
        else if(reqHeight <= 0){
            // Raw height and width of image
            final int width = options.outWidth;
            if (width > reqWidth) {

                final int halfWidth = width / 2;

                // Calculate the largest inSampleSize value that is a power of 2 and keeps both
                // height and width larger than the requested height and width.
                while ((halfWidth / inSampleSize) >= reqWidth) {
                    inSampleSize *= 2;
                }
            }
        }
        else{
            // Raw height and width of image
            final int height = options.outHeight;
            final int width = options.outWidth;
            if (height > reqHeight || width > reqWidth) {

                final int halfHeight = height / 2;
                final int halfWidth = width / 2;

                // Calculate the largest inSampleSize value that is a power of 2 and keeps both
                // height and width larger than the requested height and width.
                while ((halfHeight / inSampleSize) >= reqHeight
                        && (halfWidth / inSampleSize) >= reqWidth) {
                    inSampleSize *= 2;
                }
            }
        }

        return inSampleSize;
    }

    /**
     * 从inputStream中获取字节流 数组大小
     **/
    public static byte[] readStream(InputStream inStream) throws Exception {
        ByteArrayOutputStream outStream = new ByteArrayOutputStream();
        byte[] buffer = new byte[1024];
        int len = 0;
        while ((len = inStream.read(buffer)) != -1) {
            outStream.write(buffer, 0, len);
        }
        outStream.close();
        inStream.close();
        return outStream.toByteArray();
    }


    /**
     * Gets the content:// URI from the given corresponding path to a file
     *
     * @param context
     * @param filePath
     * @return content Uri
     */
    public static Uri getImageContentUri(Context context, String filePath) {

        Cursor cursor = context.getContentResolver().query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                new String[]{MediaStore.Images.Media._ID}, MediaStore.Images.Media.DATA + "=? ",
                new String[]{filePath}, null);
        if (cursor != null && cursor.moveToFirst()) {
            @SuppressLint("Range") int id = cursor.getInt(cursor.getColumnIndex(MediaStore.MediaColumns._ID));
            Uri baseUri = Uri.parse("content://media/external/images/media");
            cursor.close();
            return Uri.withAppendedPath(baseUri, "" + id);
        } else {
            if(cursor != null){
                cursor.close();
            }
            ContentValues values = new ContentValues();
            values.put(MediaStore.Images.Media.DATA, filePath);
            return context.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        }
    }

    private static int getOrientation(Context context, String photoPath) {

        int result = 0;


        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                Uri uri = getImageContentUri(context, photoPath);
                Cursor cursor = context.getContentResolver().query(uri,
                        new String[]{MediaStore.Images.ImageColumns.ORIENTATION}, null, null, null);

                if (cursor == null || cursor.getCount() != 1) {
                    if(cursor != null){
                        cursor.close();;
                    }
                    return -1;
                }

                cursor.moveToFirst();
                result = cursor.getInt(0);
                cursor.close();
            } catch (Exception ignored) {
                result = -1;
            }
        } else {
            try {
                ExifInterface exif = new ExifInterface(photoPath);
                int orientation = exif.getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL);

                switch (orientation) {
                    case ExifInterface.ORIENTATION_ROTATE_90:
                        result = 90;
                        break;
                    case ExifInterface.ORIENTATION_ROTATE_180:
                        result = 180;
                        break;
                    case ExifInterface.ORIENTATION_ROTATE_270:
                        result = 270;
                        break;
                }
            } catch (Exception ignore) {
                return -1;
            }
        }
        return result;
    }


    private static String getLastPathSegment(String content) {
        if (content == null || content.length() == 0) {
            return "";
        }
        String[] segments = content.split("/");
        if (segments.length > 0) {
            return segments[segments.length - 1];
        }
        return "";
    }

    @SuppressLint("Range")
    private void getAssetsFromCatalog() {

        MethodCall call = this.methodCall;
        MethodChannel.Result result = this.pendingResult;


        if(call == null || result == null)
        {
            Map requestInfo = (Map)permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION));
            if(requestInfo == null)
            {
                return;
            }

            call = (MethodCall)requestInfo.get("call");
            result = (MethodChannel.Result)requestInfo.get("result");

        }

        Uri uri = MediaStore.Files.getContentUri("external");

        Map arguments = (Map) call.arguments;
        boolean desc = (boolean) arguments.get("desc");

        final String sortOrder = desc ? MediaStore.Files.FileColumns.DATE_MODIFIED + " DESC" : MediaStore.Files.FileColumns.DATE_MODIFIED;

        int type = (int) arguments.get("type");

        final String selection = type == -1 ? MediaStore.Files.FileColumns.MEDIA_TYPE + "=? OR "
                + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=? OR "
                + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=?" :
                type == 3 ? MediaStore.Files.FileColumns.MEDIA_TYPE + "=? OR "
                        + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=?" :
                MediaStore.Files.FileColumns.MEDIA_TYPE + "=?";

        final String[] selectionArgs = type == -1 ? new String[]{
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE),
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO)
        } : type == 3 ? new String[]{
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE),
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
        } :new String[]{
                String.valueOf(type == 0 ?
                        MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE : type == 1 ?
                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO : MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO),
        };

        final String[] projections = new String[]{
                MediaStore.Files.FileColumns._ID, MediaStore.MediaColumns.DATA,
                MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.DATE_MODIFIED,
                MediaStore.MediaColumns.MIME_TYPE, MediaStore.Files.FileColumns.MEDIA_TYPE, MediaStore.MediaColumns.WIDTH, MediaStore
                .MediaColumns.HEIGHT, MediaStore.MediaColumns.SIZE, MediaStore.Images.ImageColumns.ORIENTATION,
                MediaStore.Video.VideoColumns.DURATION
        };


        // 获取ContentResolver
        ContentResolver contentResolver = context.getContentResolver();
        Cursor cursor = contentResolver.query(uri, projections, selection, selectionArgs, sortOrder);


        ArrayList allChildren = new ArrayList<Map<String, Object>>();

        if (cursor != null && cursor.moveToFirst()) {

            int idCol = cursor.getColumnIndex(MediaStore.Files.FileColumns._ID);
            int mimeType = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE);
            int mediaTypeCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.MEDIA_TYPE);
            int pathCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA);
            int orientationCol = cursor.getColumnIndex(MediaStore.Images.ImageColumns.ORIENTATION);
//      int sizeCol = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE);

            int WidthCol = cursor.getColumnIndex(MediaStore.MediaColumns.WIDTH);
            int HeightCol = cursor.getColumnIndex(MediaStore.MediaColumns.HEIGHT);


            do {

                final String path = cursor.getString(pathCol);

                String folderPath = new File(path).getParentFile().getAbsolutePath();
                String albumName = getLastPathSegment(folderPath);
                if(albumName.equals("picture"))
                {
                    continue;
                }

                String mintType = cursor.getString(mimeType);
                long fileId = cursor.getLong(idCol);
                int mtInt = Integer.parseInt(cursor.getString(mediaTypeCol));

                if (TextUtils.isEmpty(path) || TextUtils.isEmpty(mintType) || mtInt < 1 || mtInt > 3) {

                    continue;
                }

                int width = cursor.getInt(WidthCol);
                int height = cursor.getInt(HeightCol);
//
//                File file = new File(path);
//                if (!file.exists() || !file.isFile()) {
//                    continue;
//                }

                long duration = 0;

                if(mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE){
                    int orientation = cursor.getInt(orientationCol);
                    if (orientation == 90 || orientation == 270) {
                        int temp = width;
                        width = height;
                        height = temp;
                    }
                }
                else {
                    duration = cursor.getLong(cursor.getColumnIndex(MediaStore.Video.VideoColumns.DURATION))/1000;
                }


                int mdType = mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE ? 0 : mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ? 1 : 2;

                Map<String, Object> photoInfo = new HashMap();
                photoInfo.put("identifier", path);
                photoInfo.put("width", width);
                photoInfo.put("height", height);
                photoInfo.put("mediaType",mdType);
                photoInfo.put("duration",duration);
                photoInfo.put("fileId",fileId);

                allChildren.add(photoInfo);

            } while (cursor.moveToNext());

            cursor.close();
        }

        permissionRequest.remove(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION));

        result.success(allChildren);
        clearMethodCallAndResult();
    }

    @SuppressLint("Range")
    private void getAllAssetCatalog() {

        MethodCall call = this.methodCall;
        MethodChannel.Result result = this.pendingResult;


        if(call == null || result == null)
        {
            Map requestInfo = (Map)permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL));
            if(requestInfo == null)
            {
                return;
            }

            call = (MethodCall)requestInfo.get("call");
            result = (MethodChannel.Result)requestInfo.get("result");

        }

        final MethodCall tmpCall = call;
        final MethodChannel.Result tmpResult = result;

        permissionRequest.remove(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL));
        clearMethodCallAndResult();

        threadPoolExecutorCache.execute(new Runnable() {
            @Override
            public void run() {
                Uri uri = MediaStore.Files.getContentUri("external");

                Map arguments = (Map) tmpCall.arguments;

                boolean desc = (boolean) arguments.get("desc");

                final String sortOrder = desc ? MediaStore.Files.FileColumns.DATE_MODIFIED + " DESC" : MediaStore.Files.FileColumns.DATE_MODIFIED;

                int type = (int) arguments.get("type");

                final String selection = type == -1 ? MediaStore.Files.FileColumns.MEDIA_TYPE + "=? OR "
                        + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=? OR "
                        + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=?" : type == 3 ? MediaStore.Files.FileColumns.MEDIA_TYPE + "=? OR "
                        + MediaStore.Files.FileColumns.MEDIA_TYPE +  "=?" : MediaStore.Files.FileColumns.MEDIA_TYPE + "=?";


                final String albumItem_all_name = type == -1 || type == 3 ? "所有媒体" : type == 0 ? "所有照片" : type == 1 ? "所有视频" : "所有音频";

                final String[] selectionArgs = type == -1 ? new String[]{
                        String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE),
                        String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
                        String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO)
                } : type == 3 ? new String[]{
                        String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE),
                        String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO)
                } :
                        new String[]{
                                String.valueOf(type == 0 ?
                                        MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE : type == 1 ?
                                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO : MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO),
                        };

                String[] projections = new String[]{MediaStore.Files.FileColumns._ID, MediaStore.MediaColumns.DATA,
                        MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.DATE_MODIFIED,
                        MediaStore.MediaColumns.MIME_TYPE,MediaStore.Files.FileColumns.MEDIA_TYPE, MediaStore.MediaColumns.WIDTH, MediaStore
                        .MediaColumns.HEIGHT, MediaStore.MediaColumns.SIZE, MediaStore.Images.ImageColumns.ORIENTATION,
                        MediaStore.Images.ImageColumns.BUCKET_DISPLAY_NAME,
                        MediaStore.Video.VideoColumns.DURATION
//                    MediaStore.Images.ImageColumns.BUCKET_ID
                };


                // 获取ContentResolver
                ContentResolver contentResolver = context.getContentResolver();
                Cursor cursor = contentResolver.query(uri, projections, selection, selectionArgs, sortOrder);




                Map<String, Map> collectionAlbum = new LinkedHashMap<>();
                Map<String, Object> allMap = new HashMap<>();
                ArrayList<Map<String, Object>> allChildren = new ArrayList<>();
                allMap.put("identifier", "all_identifier");
                allMap.put("name", albumItem_all_name);

                allMap.put("children", allChildren);


                collectionAlbum.put(albumItem_all_name, allMap);
                Map<String, Object> allVideo = null;
                ArrayList allVideoChildren = null;
                if(type == 3 || type == -1){
                    allVideo  = new HashMap<>();
                    allVideoChildren = new ArrayList<Map<String, Object>>();
                    allVideo.put("identifier", "all_video");
                    allVideo.put("name", "所有视频");
                    allVideo.put("children", allVideoChildren);
                    collectionAlbum.put("____asset_all_video___", allVideo);
                }

                if (cursor != null && cursor.moveToFirst()) {

                    int idCol = cursor.getColumnIndex(MediaStore.Files.FileColumns._ID);
                    int mimeType = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE);
                    int mediaTypeCol = cursor.getColumnIndex(MediaStore.Files.FileColumns.MEDIA_TYPE);
                    int pathCol = cursor.getColumnIndex(MediaStore.MediaColumns.DATA);
                    int orientationCol = cursor.getColumnIndex(MediaStore.Images.ImageColumns.ORIENTATION);
                    int WidthCol = cursor.getColumnIndex(MediaStore.MediaColumns.WIDTH);
                    int HeightCol = cursor.getColumnIndex(MediaStore.MediaColumns.HEIGHT);

                    int bucketNameCol = cursor.getColumnIndex(MediaStore.Images.ImageColumns.BUCKET_DISPLAY_NAME);
                    do {
                        final String path = cursor.getString(pathCol);
                        String mintType = cursor.getString(mimeType);
                        long fileId = cursor.getLong(idCol);
                        int mtInt = Integer.parseInt(cursor.getString(mediaTypeCol));

                        if (TextUtils.isEmpty(path) || TextUtils.isEmpty(mintType) || mtInt < 1 || mtInt > 3) {

                            continue;
                        }

                        int width = cursor.getInt(WidthCol);
                        int height = cursor.getInt(HeightCol);

                        long duration = 0;

                        if(mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE){
                            int orientation = cursor.getInt(orientationCol);
                            if (orientation == 90 || orientation == 270) {
                                int temp = width;
                                width = height;
                                height = temp;
                            }
                        }
                        else{
                            duration = cursor.getLong(cursor.getColumnIndex(MediaStore.Video.VideoColumns.DURATION))/1000;
                        }

                        int mdType = mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE ? 0 : mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO ? 1 : 2;

                        String albumName = cursor.getString(bucketNameCol);
                        if(albumName.equals("WeiXin")){
                            albumName = "微信";
                        }
                        else if(albumName.equals("Screenshots")){
                            albumName = "截屏";
                        }
                        else if(albumName.equals("Download")){
                            albumName = "下载";
                        }
                        else if(albumName.equals("Camera")){
                            albumName = "相机";
                        }


                        Map<String, Object> photoInfo = new HashMap();
                        photoInfo.put("identifier", path);
                        photoInfo.put("fileId",fileId);
                        photoInfo.put("width", width);
                        photoInfo.put("height", height);
                        photoInfo.put("mediaType",mdType);
                        photoInfo.put("duration",duration);

                        allChildren.add(photoInfo);
                        if(allVideoChildren != null && mtInt == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO){
                            allVideoChildren.add(photoInfo);
                        }

                        Map album = collectionAlbum.get(albumName);
                        if (album == null) {
                            // 添加当前图片的专辑到专辑模型实体中
                            String folderPath = new File(path).getParentFile().getAbsolutePath();
                            ArrayList<Map<String, Object>> children = new ArrayList<>();
                            album = new HashMap<String, Object>();
                            album.put("identifier", folderPath);
                            album.put("name", albumName);
                            children.add(photoInfo);
                            album.put("children", children);

                            collectionAlbum.put(albumName, album);
                        } else {
                            ArrayList children = (ArrayList) album.get("children");
                            children.add(photoInfo);
                        }

                    } while (cursor.moveToNext());
                    cursor.close();
                }

                int lens = collectionAlbum.size();
                if(lens > 1){

                    final Iterator<Map.Entry<String, Map>> collectionIterator = collectionAlbum.entrySet().iterator();
                    while (collectionIterator.hasNext()){
                        Map.Entry<String, Map> stringMapEntry = collectionIterator.next();
                        final Map value = stringMapEntry.getValue();
                        final String entryId = (String) value.get("identifier");
                        if (!entryId.equals("all_identifier") && !entryId.equals("all_video") && !entryId.equals("____asset_all_video___")) {
                            final ArrayList<Map<String, Object>> entryChild = (ArrayList<Map<String, Object>>) value.get("children");
                            if(!entryChild.isEmpty()){
                                try {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        final DirectoryStream<Path> stream = Files.newDirectoryStream(new File(entryId).toPath());
                                        final ArrayList<String> filePaths = new ArrayList<>();
                                        for (Path path : stream) {
                                            filePaths.add(path.toString());
                                        }
                                        final Iterator<Map<String, Object>> iterator = entryChild.iterator();
                                        while (iterator.hasNext()){
                                            final Map<String, Object> child = iterator.next();
                                            final String childPath = (String) child.get("identifier");
                                            if(!filePaths.contains(childPath)){
                                                iterator.remove();
                                                allChildren.remove(child);
                                            }
                                        }
                                        if(entryChild.isEmpty()){
                                            collectionIterator.remove();
                                        }
                                    } else {
                                        final String[] filePaths = new File(entryId).list();
                                        if(filePaths != null && filePaths.length > 0){
                                            final Iterator<Map<String, Object>> iterator = entryChild.iterator();
                                            while (iterator.hasNext()){
                                                final Map<String, Object> child = iterator.next();
                                                final String childPath = (String) child.get("identifier");
                                                boolean exist = false;
                                                for (String filePath : filePaths) {
                                                    if (childPath.endsWith(filePath)) {
                                                        exist = true;
                                                        break;
                                                    }
                                                }
                                                if(!exist){
                                                    iterator.remove();
                                                    allChildren.remove(child);
                                                }
                                            }
                                            if(entryChild.isEmpty()){
                                                collectionIterator.remove();
                                            }
                                        }
                                    }

                                } catch (Exception e) {
                                    e.printStackTrace();
                                }
                            }

                        }
                    }

//                    for (Map.Entry<String, Map> stringMapEntry : collectionAlbum.entrySet()) {
//
//                    }

                }

                if(allVideo != null && allVideoChildren.isEmpty()){
                    collectionAlbum.remove("____asset_all_video___");
                }

                ArrayList arrayList = new ArrayList();
                arrayList.addAll(collectionAlbum.values());
                tmpResult.success(arrayList);
            }
        });

    }

    private boolean requestPermission(int requestCode) {

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU){
            if (ContextCompat.checkSelfPermission(this.activity, Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this.activity, Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this.activity, Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED
                    ||
            ContextCompat.checkSelfPermission(this.activity, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
            )

            {
                if(permissionRequest.isEmpty()) {
                    Map<String,Object> requestInfo = new HashMap<>();
                    requestInfo.put("call",this.methodCall);
                    requestInfo.put("result",this.pendingResult);
                    permissionRequest.put(String.valueOf(requestCode),requestInfo);
                    ActivityCompat.requestPermissions(this.activity,
                            new String[]{
                                    Manifest.permission.READ_MEDIA_AUDIO,
                                    Manifest.permission.READ_MEDIA_IMAGES,
                                    Manifest.permission.READ_MEDIA_VIDEO,
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                            },
                            requestCode);
                }
                else
                {
                    Map<String,Object> requestInfo = new HashMap<>();
                    requestInfo.put("call",this.methodCall);
                    requestInfo.put("result",this.pendingResult);
                    permissionRequest.put(String.valueOf(requestCode),requestInfo);
                }
                clearMethodCallAndResult();
                return false;

            }
        }
        else if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M){
            if (ContextCompat.checkSelfPermission(this.activity, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                    ||
                    ContextCompat.checkSelfPermission(this.activity, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED)
            {
                if(permissionRequest.isEmpty()) {
                    Map<String,Object> requestInfo = new HashMap<>();
                    requestInfo.put("call",this.methodCall);
                    requestInfo.put("result",this.pendingResult);
                    permissionRequest.put(String.valueOf(requestCode),requestInfo);
                    ActivityCompat.requestPermissions(this.activity,
                            new String[]{
                                    Manifest.permission.READ_EXTERNAL_STORAGE,
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                            },
                            requestCode);
                }
                else
                {
                    Map<String,Object> requestInfo = new HashMap<>();
                    requestInfo.put("call",this.methodCall);
                    requestInfo.put("result",this.pendingResult);
                    permissionRequest.put(String.valueOf(requestCode),requestInfo);
                }
                clearMethodCallAndResult();
                return false;

            }
        }

        return true;

    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {


        if (permissionRequest.isEmpty() || (requestCode != REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL && requestCode != REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION)) {
            return false;
        }

        boolean allGranted = true;

        for (int grantResult : grantResults) {
            if (grantResult != PackageManager.PERMISSION_GRANTED) {
                allGranted = false;
                break;
            }
        }


//        if (permissions.length == 2) {
//            if (grantResults[0] == PackageManager.PERMISSION_GRANTED &&
//                    grantResults[1] == PackageManager.PERMISSION_GRANTED)
//            {
//                if(permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL)) != null) {
//                    getAllAssetCatalog();
//                }
//                if(permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION)) != null) {
//                    getAssetsFromCatalog();
//                }
//            } else {
//                for(Object value : permissionRequest.values()){
//                    Map requestInfo = (Map) value;
//                    MethodChannel.Result result = (MethodChannel.Result)requestInfo.get("result");
//                    result.error("-1000", "用户拒绝访问相册!", null);
//                }
//
//                permissionRequest.clear();
//                clearMethodCallAndResult();
//                return false;
//            }
//
//            return true;
//        }

        if(allGranted){
            if(permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_ALL)) != null) {
                getAllAssetCatalog();
            }
            if(permissionRequest.get(String.valueOf(REQUEST_CODE_GRANT_PERMISSIONS_ASSET_COLLECTION)) != null) {
                getAssetsFromCatalog();
            }
        }
        else{
            for(Object value : permissionRequest.values()){
                Map requestInfo = (Map) value;
                MethodChannel.Result result = (MethodChannel.Result)requestInfo.get("result");
                result.error("-1000", "用户拒绝访问相册!", null);
            }
        }

        permissionRequest.clear();
        clearMethodCallAndResult();

        return allGranted;
    }

//    private void finishWithError(String errorCode, String errorMessage) {
//        if (pendingResult != null)
//            pendingResult.error(errorCode, errorMessage, null);
//        clearMethodCallAndResult();
//    }

    private void clearMethodCallAndResult() {
        this.methodCall = null;
        this.pendingResult = null;
    }

}
