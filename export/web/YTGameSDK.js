/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// This object will be exposed on the window to be called from Godot.
// It interfaces with the YouTube Playables Game SDK.
window.YTGameSDK_Godot = {
    // Helper to check if we are in the Playables environment.
    _inEnv: function() {
        return typeof ytgame !== 'undefined' && ytgame.IN_PLAYABLES_ENV;
    },

    getSDKVersion: function() {
        return this._inEnv() ? ytgame.SDK_VERSION : "N/A";
    },

    sendScore: function(score) {
        if (this._inEnv()) {
            ytgame.engagement.sendScore({ value: score });
        }
    },

    firstFrameReady: function() {
        if (this._inEnv()) {
            ytgame.game.firstFrameReady();
        }
    },

    gameReady: function() {
        if (this._inEnv()) {
            ytgame.game.gameReady();
        }
    },

    saveData: function(playableSaveData) {
        if (this._inEnv()) {
            ytgame.game.saveData(playableSaveData).then(() => {
                // Handle data save success.
                window.GodotYTCallbacks.onSaveSuccess();
            }, (e) => {
                // Send an error to YouTube
                ytgame.health.logError();
                // Handle data save failure.
                window.GodotYTCallbacks.onSaveFailed(e.toString());
            });
        } else {
            window.GodotYTCallbacks.onSaveFailed("Not in Playables Environment.");
        }
    },

    loadData: function() {
        if (this._inEnv()) {
            ytgame.game.loadData().then((data) => {
                window.GodotYTCallbacks.onLoadDataReceived(data.toString());
            });
        }
    },

    logError: function(errorMessage) {
        console.error(errorMessage);
        if (this._inEnv()) {
            // Send an error to YouTube
            ytgame.health.logError();
        }
    },

    logWarning: function(warningMessage) {
        console.debug(warningMessage);
        if (this._inEnv()) {
            // Send a warning to YouTube
            ytgame.health.logWarning();
        }
    },

    isAudioEnabled: function() {
        return this._inEnv() ? ytgame.system.isAudioEnabled() : true;
    },

    inPlayablesEnv: function() {
        return this._inEnv();
    },

    requestInterstitialAd: function() {
        if (this._inEnv()) {
            ytgame.ads.requestInterstitialAd().then(() => {
                // Ad request successful
                window.GodotYTCallbacks.onAdSuccess();
            }, (e) => {
                // Ad not shown or other failure.
                window.GodotYTCallbacks.onAdFailed(e.toString());
            });
        } else {
            window.GodotYTCallbacks.onAdFailed("Not in Playables Environment.");
        }
    },

    // This function will be called from Godot to set up the listeners.
    setAllCallbacks: function() {
        if (this._inEnv()) {
            ytgame.system.onAudioEnabledChange((isAudioEnabled) => {
                window.GodotYTCallbacks.onAudioEnabledChanged(isAudioEnabled);
            });
            ytgame.system.onPause(() => {
                window.GodotYTCallbacks.onGamePaused();
            });
            ytgame.system.onResume(() => {
                window.GodotYTCallbacks.onGameResumed();
            });
        }
    }
};
