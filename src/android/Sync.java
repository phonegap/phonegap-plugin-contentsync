/*
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

package com.adobe.phonegap.contentsync;

import java.io.BufferedInputStream;
import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.HttpURLConnection;
import java.net.URLConnection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.zip.GZIPInputStream;
import java.util.zip.Inflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaResourceApi;
import org.apache.cordova.CordovaResourceApi.OpenForReadResult;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.net.Uri;
import android.os.Environment;
import android.os.StatFs;
import android.util.Log;
import android.webkit.CookieManager;

public class Sync extends CordovaPlugin {
	private static final String STATUS_INSTALLING = "installing";
	private static final String PROP_LOCAL_PATH = "localPath";
	private static final String STATUS_DOWNLOADING = "downloading";
	private static final String PROP_STATUS = "status";
	private static final String PROP_PROGRESS = "progress";
	// Type
	private static final String TYPE_REPLACE = "replace";
	private static final String TYPE_MERGE = "merge";

	private static final String LOG_TAG = "ContentSync";

	private static HashMap<String, RequestContext> activeRequests = new HashMap<String, RequestContext>();
    private static final int MAX_BUFFER_SIZE = 16 * 1024;

    private static final class RequestContext {
        String source;
        String target;
        File targetFile;
        CallbackContext callbackContext;
        HttpURLConnection connection;
        boolean aborted;
        RequestContext(String source, String target, CallbackContext callbackContext) {
            this.source = source;
            this.target = target;
            this.callbackContext = callbackContext;
        }
        void sendPluginResult(PluginResult pluginResult) {
            synchronized (this) {
                if (!aborted) {
                    callbackContext.sendPluginResult(pluginResult);
                }
            }
        }
    }

	@Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("sync")) {
        	String src = args.getString(0);
        	String id = args.getString(1);
        	String type = args.optString(2, TYPE_REPLACE);
        	JSONObject headers = args.optJSONObject(3);
        	if (headers == null) {
        		headers = new JSONObject();
        	}
        	Log.d(LOG_TAG, "sync called with id = " + id + " and src = " + src + "!");

        	download(src, id, type, headers, callbackContext);

            return true;
        } else if (action.equals("cancel")) {
        	Log.d(LOG_TAG, "not implemented, yet");
        }
        return false;
    }

	/**
     * Adds an interface method to an InputStream to return the number of bytes
     * read from the raw stream. This is used to track total progress against
     * the HTTP Content-Length header value from the server.
     */
    private static abstract class TrackingInputStream extends FilterInputStream {
      public TrackingInputStream(final InputStream in) {
        super(in);
      }
        public abstract long getTotalRawBytesRead();
  }

    private static class ExposedGZIPInputStream extends GZIPInputStream {
      public ExposedGZIPInputStream(final InputStream in) throws IOException {
        super(in);
      }
      public Inflater getInflater() {
        return inf;
      }
  }

    /**
     * Provides raw bytes-read tracking for a GZIP input stream. Reports the
     * total number of compressed bytes read from the input, rather than the
     * number of uncompressed bytes.
     */
    private static class TrackingGZIPInputStream extends TrackingInputStream {
      private ExposedGZIPInputStream gzin;
      public TrackingGZIPInputStream(final ExposedGZIPInputStream gzin) throws IOException {
        super(gzin);
        this.gzin = gzin;
      }
      public long getTotalRawBytesRead() {
        return gzin.getInflater().getBytesRead();
      }
  }

    /**
     * Provides simple total-bytes-read tracking for an existing InputStream
     */
    private static class SimpleTrackingInputStream extends TrackingInputStream {
        private long bytesRead = 0;
        public SimpleTrackingInputStream(InputStream stream) {
            super(stream);
        }

        private int updateBytesRead(int newBytesRead) {
          if (newBytesRead != -1) {
            bytesRead += newBytesRead;
          }
          return newBytesRead;
        }

        @Override
        public int read() throws IOException {
            return updateBytesRead(super.read());
        }

        // Note: FilterInputStream delegates read(byte[] bytes) to the below method,
        // so we don't override it or else double count (CB-5631).
        @Override
        public int read(byte[] bytes, int offset, int count) throws IOException {
            return updateBytesRead(super.read(bytes, offset, count));
        }

        public long getTotalRawBytesRead() {
          return bytesRead;
        }
    }

	private void download(final String source, final String id, final String type, final JSONObject headers, final CallbackContext callbackContext) {
        Log.d(LOG_TAG, "download " + source);

        final CordovaResourceApi resourceApi = webView.getResourceApi();
        final Uri sourceUri = resourceApi.remapUri(Uri.parse(source));

        final boolean trustEveryone = false;
        int uriType = CordovaResourceApi.getUriType(sourceUri);
        final boolean useHttps = uriType == CordovaResourceApi.URI_TYPE_HTTPS;
        final boolean isLocalTransfer = !useHttps && uriType != CordovaResourceApi.URI_TYPE_HTTP;


        final RequestContext context = new RequestContext(source, id, callbackContext);
        synchronized (activeRequests) {
            activeRequests.put(id, context);
        }

        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                if (context.aborted) {
                    return;
                }
                HttpURLConnection connection = null;
                HostnameVerifier oldHostnameVerifier = null;
                SSLSocketFactory oldSocketFactory = null;
                File file = null;
                PluginResult result = null;
                TrackingInputStream inputStream = null;
                boolean cached = false;

                OutputStream outputStream = null;
                try {
                    OpenForReadResult readResult = null;

                    File outputDir = cordova.getActivity().getCacheDir();
                    file = File.createTempFile(id, ".tmp", outputDir);
                    final Uri targetUri = resourceApi.remapUri(Uri.fromFile(file));


                    context.targetFile = file;

                    Log.d(LOG_TAG, "Download file:" + sourceUri);
                    Log.d(LOG_TAG, "Target file:" + file);
                    Log.d(LOG_TAG, "size = " + file.length());

                    ProgressEvent progress = new ProgressEvent();
                    progress.setStatus(STATUS_DOWNLOADING);

                    if (isLocalTransfer) {
                        readResult = resourceApi.openForRead(sourceUri);
                        if (readResult.length != -1) {
                            progress.setTotal(readResult.length);
                        }
                        inputStream = new SimpleTrackingInputStream(readResult.inputStream);
                    } else {
                        // connect to server
                        // Open a HTTP connection to the URL based on protocol
                        connection = resourceApi.createHttpConnection(sourceUri);
                        if (useHttps && trustEveryone) {
                            // Setup the HTTPS connection class to trust everyone
                            HttpsURLConnection https = (HttpsURLConnection)connection;
                            oldSocketFactory = trustAllHosts(https);
                            // Save the current hostnameVerifier
                            oldHostnameVerifier = https.getHostnameVerifier();
                            // Setup the connection not to verify hostnames
                            https.setHostnameVerifier(DO_NOT_VERIFY);
                        }

                        connection.setRequestMethod("GET");

                        // TODO: Make OkHttp use this CookieManager by default.
                        String cookie = getCookies(sourceUri.toString());

                        if(cookie != null)
                        {
                            connection.setRequestProperty("cookie", cookie);
                        }

                        // This must be explicitly set for gzip progress tracking to work.
                        connection.setRequestProperty("Accept-Encoding", "gzip");

                        // Handle the other headers
                        if (headers != null) {
                            addHeadersToRequest(connection, headers);
                        }

                        connection.connect();
                        if (connection.getResponseCode() == HttpURLConnection.HTTP_NOT_MODIFIED) {
                            cached = true;
                            connection.disconnect();
                            Log.d(LOG_TAG, "Resource not modified: " + source);
                            JSONObject error = new JSONObject();
                            result = new PluginResult(PluginResult.Status.ERROR, error);
                        } else {
                            if (connection.getContentEncoding() == null || connection.getContentEncoding().equalsIgnoreCase("gzip")) {
                                // Only trust content-length header if we understand
                                // the encoding -- identity or gzip
                            	int connectionLength = connection.getContentLength();
                                if (connectionLength != -1) {
                                	if (connectionLength > getFreeSpace()) {
                                		cached = true;
                                		connection.disconnect();
                                        JSONObject error = new JSONObject();
                                        error.put("message", "Not enough free space to download");
                                        result = new PluginResult(PluginResult.Status.ERROR, error);
                                	} else {
                                        progress.setTotal(connectionLength);
                                	}
                                }
                            }
                            inputStream = getInputStream(connection);
                        }
                    }

                    if (!cached) {
                        try {
                            synchronized (context) {
                                if (context.aborted) {
                                    return;
                                }
                                context.connection = connection;
                            }

                            // write bytes to file
                            byte[] buffer = new byte[MAX_BUFFER_SIZE];
                            int bytesRead = 0;
                            outputStream = resourceApi.openOutputStream(targetUri);
                            while ((bytesRead = inputStream.read(buffer)) > 0) {
                                Log.d(LOG_TAG, "bytes read = " + bytesRead);
                                outputStream.write(buffer, 0, bytesRead);
                                // Send a progress event.
                                progress.setLoaded(inputStream.getTotalRawBytesRead());

                                updateProgress(callbackContext, progress);
                            }

                            unzip(context.targetFile, id, type, callbackContext);

                        } finally {
                            synchronized (context) {
                                context.connection = null;
                            }
                            safeClose(inputStream);
                            safeClose(outputStream);
                        }
                    }

                } catch (FileNotFoundException e) {
                    JSONObject error = new JSONObject();
                    Log.e(LOG_TAG, error.toString(), e);
                    result = new PluginResult(PluginResult.Status.IO_EXCEPTION, error);
                    callbackContext.sendPluginResult(result);
                } catch (IOException e) {
                    JSONObject error = new JSONObject();
                    Log.e(LOG_TAG, error.toString(), e);
                    result = new PluginResult(PluginResult.Status.IO_EXCEPTION, error);
                    callbackContext.sendPluginResult(result);
                } catch (JSONException e) {
                    Log.e(LOG_TAG, e.getMessage(), e);
                    result = new PluginResult(PluginResult.Status.JSON_EXCEPTION);
                    callbackContext.sendPluginResult(result);
                } catch (Throwable e) {
                    JSONObject error = new JSONObject();
                    Log.e(LOG_TAG, error.toString(), e);
                    result = new PluginResult(PluginResult.Status.IO_EXCEPTION, error);
                    callbackContext.sendPluginResult(result);
                } finally {
//                    synchronized (activeRequests) {
//                        activeRequests.remove(id);
//                    }

                    if (connection != null) {
                        // Revert back to the proper verifier and socket factories
                        if (trustEveryone && useHttps) {
                            HttpsURLConnection https = (HttpsURLConnection) connection;
                            https.setHostnameVerifier(oldHostnameVerifier);
                            https.setSSLSocketFactory(oldSocketFactory);
                        }
                    }

                    // Remove incomplete download.
                    if (!cached && result.getStatus() != PluginResult.Status.OK.ordinal() && file != null) {
                        file.delete();
                    }
                }
            }
        });
    }

	private long getFreeSpace() {
		File path = Environment.getDataDirectory();
        StatFs stat = new StatFs(path.getPath());
        long blockSize = stat.getBlockSize();
        long availableBlocks = stat.getAvailableBlocks();
        return availableBlocks * blockSize;
    }

	private void unzip(final File targetFile, final String id, String type, final CallbackContext callbackContext) throws JSONException {
		Log.d(LOG_TAG, "type = " + type);
		Log.d(LOG_TAG, "downloaded = " + targetFile.getAbsolutePath());

		// unzip
		//String outputDirectory = cordova.getActivity().getFilesDir().getAbsolutePath();
		String outputDirectory = cordova.getActivity().getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath();
		outputDirectory += outputDirectory.endsWith(File.separator) ? "" : File.separator;
		outputDirectory += id;
		Log.d(LOG_TAG, "output dir = " + outputDirectory);

		// Backup existing directory
		File dir = new File(outputDirectory);
		File backup = new File(outputDirectory + ".bak");
		if (dir.exists()) {
			if (type.equals(TYPE_MERGE)) {
				try {
					copyFolder(dir, backup);
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
			} else {
				dir.renameTo(backup);
			}
		}

		if (unzipSync(targetFile, outputDirectory, callbackContext)) {
			// success, remove backup
			removeFolder(backup);
		} else {
			// failure, revert backup
			removeFolder(dir);
			backup.renameTo(dir);
		}

		// delete temp file
		targetFile.delete();

		// complete
		JSONObject result = new JSONObject();
		result.put(PROP_LOCAL_PATH, getUriForArg(outputDirectory));
        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, result));
	}

	private static TrackingInputStream getInputStream(URLConnection conn) throws IOException {
        String encoding = conn.getContentEncoding();
        if (encoding != null && encoding.equalsIgnoreCase("gzip")) {
          return new TrackingGZIPInputStream(new ExposedGZIPInputStream(conn.getInputStream()));
        }
        return new SimpleTrackingInputStream(conn.getInputStream());
    }

    private static void safeClose(Closeable stream) {
        if (stream != null) {
            try {
                stream.close();
            } catch (IOException e) {
            }
        }
    }

    private String getCookies(final String target) {
        boolean gotCookie = false;
        String cookie = null;
        Class webViewClass = webView.getClass();
        try {
            Method gcmMethod = webViewClass.getMethod("getCookieManager");
            Class iccmClass  = gcmMethod.getReturnType();
            Method gcMethod  = iccmClass.getMethod("getCookie");

            cookie = (String)gcMethod.invoke(
                        iccmClass.cast(
                            gcmMethod.invoke(webView)
                        ), target);

            gotCookie = true;
        } catch (NoSuchMethodException e) {
        } catch (IllegalAccessException e) {
        } catch (InvocationTargetException e) {
        } catch (ClassCastException e) {
        }

        if (!gotCookie) {
            cookie = CookieManager.getInstance().getCookie(target);
        }

        return cookie;
    }

    private static void addHeadersToRequest(URLConnection connection, JSONObject headers) {
        try {
            for (Iterator<?> iter = headers.keys(); iter.hasNext(); ) {
                String headerKey = iter.next().toString();
                JSONArray headerValues = headers.optJSONArray(headerKey);
                if (headerValues == null) {
                    headerValues = new JSONArray();
                    headerValues.put(headers.getString(headerKey));
                }
                connection.setRequestProperty(headerKey, headerValues.getString(0));
                for (int i = 1; i < headerValues.length(); ++i) {
                    connection.addRequestProperty(headerKey, headerValues.getString(i));
                }
            }
        } catch (JSONException e1) {
          // No headers to be manipulated!
        }
    }

    /**
     * This function will install a trust manager that will blindly trust all SSL
     * certificates.  The reason this code is being added is to enable developers
     * to do development using self signed SSL certificates on their web server.
     *
     * The standard HttpsURLConnection class will throw an exception on self
     * signed certificates if this code is not run.
     */
    private static SSLSocketFactory trustAllHosts(HttpsURLConnection connection) {
        // Install the all-trusting trust manager
        SSLSocketFactory oldFactory = connection.getSSLSocketFactory();
        try {
            // Install our all trusting manager
            SSLContext sc = SSLContext.getInstance("TLS");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());
            SSLSocketFactory newFactory = sc.getSocketFactory();
            connection.setSSLSocketFactory(newFactory);
        } catch (Exception e) {
            Log.e(LOG_TAG, e.getMessage(), e);
        }
        return oldFactory;
    }

    // Create a trust manager that does not validate certificate chains
    private static final TrustManager[] trustAllCerts = new TrustManager[] { new X509TrustManager() {
        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
            return new java.security.cert.X509Certificate[] {};
        }

        public void checkClientTrusted(X509Certificate[] chain,
                String authType) throws CertificateException {
        }

        public void checkServerTrusted(X509Certificate[] chain,
                String authType) throws CertificateException {
        }
    } };


    // always verify the host - don't check for certificate
    private static final HostnameVerifier DO_NOT_VERIFY = new HostnameVerifier() {
        public boolean verify(String hostname, SSLSession session) {
            return true;
        }
    };

    /* Unzip code */

    // Can't use DataInputStream because it has the wrong endian-ness.
    private static int readInt(InputStream is) throws IOException {
        int a = is.read();
        int b = is.read();
        int c = is.read();
        int d = is.read();
        return a | b << 8 | c << 16 | d << 24;
    }

    private boolean unzipSync(File targetFile, String outputDirectory, CallbackContext callbackContext) {
    	Log.d(LOG_TAG, "unzipSync called");
    	Log.d(LOG_TAG, "zip = " + targetFile.getAbsolutePath());
        InputStream inputStream = null;
        ZipFile zip = null;
        boolean anyEntries = false;
        try {
        	zip = new ZipFile(targetFile);

            // Since Cordova 3.3.0 and release of File plugins, files are accessed via cdvfile://
            // Accept a path or a URI for the source zip.
            Uri zipUri = getUriForArg(targetFile.getAbsolutePath());
            Uri outputUri = getUriForArg(outputDirectory);

            CordovaResourceApi resourceApi = webView.getResourceApi();

            File tempFile = resourceApi.mapUriToFile(zipUri);
            if (tempFile == null || !tempFile.exists()) {
                String errorMessage = "Zip file does not exist";
                callbackContext.error(errorMessage);
                Log.e(LOG_TAG, errorMessage);
                return false;
            }

            File outputDir = resourceApi.mapUriToFile(outputUri);
            outputDirectory = outputDir.getAbsolutePath();
            outputDirectory += outputDirectory.endsWith(File.separator) ? "" : File.separator;
            if (outputDir == null || (!outputDir.exists() && !outputDir.mkdirs())){
                String errorMessage = "Could not create output directory";
                callbackContext.error(errorMessage);
                Log.e(LOG_TAG, errorMessage);
                return false;
            }

            OpenForReadResult zipFile = resourceApi.openForRead(zipUri);
            ProgressEvent progress = new ProgressEvent();
            progress.setStatus(STATUS_INSTALLING);
            progress.setTotal(zip.size());
            Log.d(LOG_TAG, "zip file len = " + zip.size());

            inputStream = new BufferedInputStream(zipFile.inputStream);
            inputStream.mark(10);
            int magic = readInt(inputStream);

            if (magic != 875721283) { // CRX identifier
                inputStream.reset();
            } else {
                // CRX files contain a header. This header consists of:
                //  * 4 bytes of magic number
                //  * 4 bytes of CRX format version,
                //  * 4 bytes of public key length
                //  * 4 bytes of signature length
                //  * the public key
                //  * the signature
                // and then the ordinary zip data follows. We skip over the header before creating the ZipInputStream.
                readInt(inputStream); // version == 2.
                int pubkeyLength = readInt(inputStream);
                int signatureLength = readInt(inputStream);

                inputStream.skip(pubkeyLength + signatureLength);
            }

            // The inputstream is now pointing at the start of the actual zip file content.
            ZipInputStream zis = new ZipInputStream(inputStream);
            inputStream = zis;

            ZipEntry ze;
            byte[] buffer = new byte[32 * 1024];

            while ((ze = zis.getNextEntry()) != null)
            {
                anyEntries = true;
                String compressedName = ze.getName();

                if (ze.getSize() > getFreeSpace()) {
                	return false;
                }

                if (ze.isDirectory()) {
                   File dir = new File(outputDirectory + compressedName);
                   dir.mkdirs();
                } else {
                    File file = new File(outputDirectory + compressedName);
                    file.getParentFile().mkdirs();
                    if(file.exists() || file.createNewFile()){
                        Log.w(LOG_TAG, "extracting: " + file.getPath());
                        FileOutputStream fout = new FileOutputStream(file);
                        int count;
                        while ((count = zis.read(buffer)) != -1)
                        {
                            fout.write(buffer, 0, count);
                        }
                        fout.close();
                    }

                }
                progress.addLoaded(1);
                updateProgress(callbackContext, progress);
                zis.closeEntry();
            }

            // final progress = 100%
//            progress.setLoaded(progress.getTotal());
//            updateProgress(callbackContext, progress);
        } catch (Exception e) {
            String errorMessage = "An error occurred while unzipping.";
            callbackContext.error(errorMessage);
            Log.e(LOG_TAG, errorMessage, e);
        } finally {
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException e) {
                }
            }
            if (zip != null) {
            	try {
            		zip.close();
            	} catch (IOException e) {
                }
            }
        }

        if (anyEntries)
            return true;
        else
            return false;
    }

    private void updateProgress(CallbackContext callbackContext, ProgressEvent progress) throws JSONException {
        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, progress.toJSONObject());
        pluginResult.setKeepCallback(true);
        callbackContext.sendPluginResult(pluginResult);
    }

    private Uri getUriForArg(String arg) {
        CordovaResourceApi resourceApi = webView.getResourceApi();
        Uri tmpTarget = Uri.parse(arg);
        return resourceApi.remapUri(
                tmpTarget.getScheme() != null ? tmpTarget : Uri.fromFile(new File(arg)));
    }

    private static class ProgressEvent {
        private long loaded;
        private long total;
        private String status;
        public long getLoaded() {
            return loaded;
        }
        public void setLoaded(long loaded) {
            this.loaded = loaded;
        }
        public void addLoaded(long add) {
            this.loaded += add;
        }
        public long getTotal() {
            return total;
        }
        public void setTotal(long total) {
            this.total = total;
        }
        public String getStatus() {
			return status;
		}
		public void setStatus(String status) {
			this.status = status;
		}
		public JSONObject toJSONObject() throws JSONException {
			JSONObject jsonProgress = new JSONObject();
			double loaded = this.getLoaded();
			double total = this.getTotal();
			double percentage = Math.floor((loaded / total * 100) / 2);
			// if we are installing then add 50% done
			if (this.getStatus() == STATUS_INSTALLING) {
				percentage += 50;
			}
			jsonProgress.put(PROP_PROGRESS, percentage);
			jsonProgress.put(PROP_STATUS, this.getStatus());
			return jsonProgress;

        }
    }

    private void copyFolder(File src, File dest) throws IOException{

    	if(src.isDirectory()) {
    		if(!dest.exists()){
    		   dest.mkdir();
    		}

    		//list all the directory contents
    		String files[] = src.list();

    		for (String file : files) {
    		   //construct the src and dest file structure
    		   File srcFile = new File(src, file);
    		   File destFile = new File(dest, file);
    		   //recursive copy
    		   copyFolder(srcFile,destFile);
    		}

    	} else {
    		//if file, then copy it
    		//Use bytes stream to support all file types
    		InputStream in = new FileInputStream(src);
    	    OutputStream out = new FileOutputStream(dest);

    	    byte[] buffer = new byte[1024];

    	    int length;
    	    //copy the file content in bytes
    	    while ((length = in.read(buffer)) > 0){
    	    	   out.write(buffer, 0, length);
    	    }

    	    in.close();
    	    out.close();
    	}
    }

    private void removeFolder(File directory) {
    	if (directory.exists()) {
            if (directory.isDirectory()) {
                for (File file : directory.listFiles()) {
                	removeFolder(file);
                }
            }
    	}
        directory.delete();
	}

}
