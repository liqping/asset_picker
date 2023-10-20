package com.works.asset_picker;

import java.util.concurrent.RejectedExecutionHandler;
import java.util.concurrent.ThreadPoolExecutor;

import io.flutter.plugin.common.MethodChannel;

public abstract  class PluginRunnable implements Runnable{
    private final MethodChannel.Result result;

    public PluginRunnable(MethodChannel.Result result) {
        this.result = result;
    }

    public static class DiscardOldestPolicy implements RejectedExecutionHandler {

        public DiscardOldestPolicy() { }

        @Override
        public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {

            if (!e.isShutdown()) {
                PluginRunnable runnable = (PluginRunnable) e.getQueue().poll();
                if(runnable != null){
                    runnable.result.error("-6", "请求被丢弃", null);
                }
                e.execute(r);
            }
        }
    }
}
