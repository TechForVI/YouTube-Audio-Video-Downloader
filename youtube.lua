require "import"
import "android.widget.*"
import "com.androlua.*"
import "android.view.View"
import "android.content.Context"
import "android.net.Uri"
import "android.os.Handler"
import "android.os.Looper"
import "java.io.File"
import "cjson"
import "android.media.MediaPlayer"
import "java.io.FileOutputStream"
import "java.lang.Thread"
import "android.graphics.Typeface"
import "android.widget.VideoView"
import "android.widget.SeekBar"
import "android.app.DownloadManager"
import "android.os.Environment"
import "java.net.URL"
import "android.view.Gravity"
import "android.content.Intent"

activity = this

local CURRENT_VERSION = "1.0"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/TechForVI/YouTube-Audio-Video-Downloader/main/"
local VERSION_URL = GITHUB_RAW_URL .. "version.txt"
local SCRIPT_URL = GITHUB_RAW_URL .. "main.lua"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/YouTube Audio Video Downloader/main.lua"
local updateInProgress = false
local updateDlg = nil
local updateAvailable = false

local vibrator = activity.getSystemService(Context.VIBRATOR_SERVICE)
local JavaRunnable = luajava.bindClass("java.lang.Runnable")
local mainHandler = luajava.new(Handler, luajava.bindClass("android.os.Looper").getMainLooper())

local currentData = nil
local audioPlayer = nil
local videoOptions = {}
local timeHandler = Handler()
local timeRunnable
local selectedFormat = "Video"
local selectedQuality = "720p"
local isProcessing = false

function checkUpdate()
    if updateInProgress then return end
    
    Http.get(VERSION_URL, function(code, onlineVersion)
        if code == 200 and onlineVersion then
            onlineVersion = tostring(onlineVersion):match("^%s*(.-)%s*$")
            if onlineVersion and onlineVersion ~= CURRENT_VERSION then
                updateAvailable = true
                showUpdateDialog(onlineVersion)
                runUi(function()
                    if updateButton then
                        updateButton.setVisibility(View.VISIBLE)
                    end
                end)
            else
                updateAvailable = false
                runUi(function()
                    if updateButton then
                        updateButton.setVisibility(View.GONE)
                    end
                end)
            end
        end
    end)
end

function showUpdateDialog(onlineVersion)
    updateDlg = LuaDialog(activity)
    updateDlg.setTitle("New Update Available!")
    updateDlg.setMessage("A new version (" .. onlineVersion .. ") is available. Would you like to update now?")
    
    updateDlg.setButton("Update Now", function()
        updateDlg.dismiss()
        downloadAndInstallUpdate()
    end)
    
    updateDlg.setButton2("Later", function()
        updateDlg.dismiss()
        updateAvailable = true
        runUi(function()
            if updateButton then
                updateButton.setVisibility(View.VISIBLE)
            end
        end)
    end)
    
    updateDlg.show()
end

function showUpdateButtonDialog()
    if not updateAvailable then return end
    
    updateDlg = LuaDialog(activity)
    updateDlg.setTitle("Update Available!")
    updateDlg.setMessage("A new version is available. Would you like to update now?")
    
    updateDlg.setButton("Update Now", function()
        updateDlg.dismiss()
        downloadAndInstallUpdate()
    end)
    
    updateDlg.setButton2("Cancel", function()
        updateDlg.dismiss()
    end)
    
    updateDlg.show()
end

function downloadAndInstallUpdate()
    updateInProgress = true
    
    local function performUpdate()
        Http.get(SCRIPT_URL, function(code, newContent)
            if code == 200 and newContent then
                local tempPath = PLUGIN_PATH .. ".temp_update"
                local backupPath = PLUGIN_PATH .. ".backup"
                
                local function restoreFromBackup()
                    if File(backupPath).exists() then
                        os.rename(backupPath, PLUGIN_PATH)
                        return true
                    end
                    return false
                end
                
                local function cleanupFiles()
                    pcall(function() os.remove(tempPath) end)
                    pcall(function() os.remove(backupPath) end)
                end
                
                local f = io.open(tempPath, "w")
                if f then
                    f:write(newContent)
                    f:close()
                    
                    if File(PLUGIN_PATH).exists() then
                        local backupFile = io.open(PLUGIN_PATH, "r")
                        if backupFile then
                            local backupContent = backupFile:read("*a")
                            backupFile:close()
                            local bf = io.open(backupPath, "w")
                            if bf then
                                bf:write(backupContent)
                                bf:close()
                            end
                        end
                    end
                    
                    local success = pcall(function()
                        os.remove(PLUGIN_PATH)
                        os.rename(tempPath, PLUGIN_PATH)
                    end)
                    
                    if success then
                        cleanupFiles()
                        updateAvailable = false
                        
                        local successDialog = LuaDialog(activity)
                        successDialog.setTitle("Update Successful")
                        successDialog.setMessage("Please restart the plugin.")
                        successDialog.setButton("OK", function()
                            successDialog.dismiss()
                            
                            runUi(function()
                                if updateButton then
                                    updateButton.setVisibility(View.GONE)
                                end
                            end)
                            
                            local handler = luajava.bindClass("android.os.Handler")(activity.getMainLooper())
                            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                                run = function()
                                    if dlg and dlg.dismiss then
                                        dlg.dismiss()
                                    end
                                end
                            }), 1000)
                        end)
                        successDialog.show()
                    else
                        local restored = restoreFromBackup()
                        cleanupFiles()
                        
                        local errorDialog = LuaDialog(activity)
                        if restored then
                            errorDialog.setTitle("Update Failed")
                            errorDialog.setMessage("Update failed. Old version restored.")
                        else
                            errorDialog.setTitle("Update Failed")
                            errorDialog.setMessage("Update failed. Please try again.")
                        end
                        errorDialog.setButton("OK", function()
                            errorDialog.dismiss()
                        end)
                        errorDialog.show()
                    end
                else
                    local errorDialog = LuaDialog(activity)
                    errorDialog.setTitle("Update Failed")
                    errorDialog.setMessage("Cannot write temporary file.")
                    errorDialog.setButton("OK", function()
                        errorDialog.dismiss()
                    end)
                    errorDialog.show()
                end
            else
                local errorDialog = LuaDialog(activity)
                errorDialog.setTitle("Update Failed")
                errorDialog.setMessage("Cannot download new script.")
                errorDialog.setButton("OK", function()
                    errorDialog.dismiss()
                end)
                errorDialog.show()
            end
            updateInProgress = false
        end)
    end
    
    Thread(JavaRunnable{
        run = performUpdate
    }).start()
end

Thread(JavaRunnable{
    run = function()
        Thread.sleep(2000)
        checkUpdate()
    end
}).start()

function showToast(message)
    mainHandler.post(JavaRunnable{
        run = function() Toast.makeText(activity, message, Toast.LENGTH_SHORT).show() end
    })
end

function runUi(func)
    mainHandler.post(JavaRunnable{ run = function() pcall(func) end })
end

function updatePlaybackTime()
    local currentPos = 0
    local duration = 0
    local isPlaying = false

    if videoPlayerView and videoPlayerView.getDuration() > 0 then
        currentPos = videoPlayerView.getCurrentPosition()
        duration = videoPlayerView.getDuration()
        isPlaying = videoPlayerView.isPlaying()
    elseif audioPlayer and audioPlayer.getDuration() > 0 then
        currentPos = audioPlayer.getCurrentPosition()
        duration = audioPlayer.getDuration()
        isPlaying = audioPlayer.isPlaying()
    end

    if duration > 0 then
        if seekBar and timeText then
            seekBar.setMax(duration)
            seekBar.setProgress(currentPos)

            local currentMinutes = math.floor(currentPos / 60000)
            local currentSeconds = math.floor((currentPos % 60000) / 1000)
            local durationMinutes = math.floor(duration / 60000)
            local durationSeconds = math.floor((duration % 60000) / 1000)

            timeText.text = string.format("%02d:%02d / %02d:%02d", currentMinutes, currentSeconds, durationMinutes, durationSeconds)
        end
    end

    timeHandler.postDelayed(timeRunnable, 1000)
end

timeRunnable = JavaRunnable { run = updatePlaybackTime }

function startUpdateTime()
    stopUpdateTime()
    timeHandler.post(timeRunnable)
end

function stopUpdateTime()
    timeHandler.removeCallbacks(timeRunnable)
end

function stopAllMedia()
    stopUpdateTime()
    if audioPlayer then
        pcall(function()
            if audioPlayer.isPlaying() then audioPlayer.stop() end
            audioPlayer.release()
        end)
        audioPlayer = nil
    end
    pcall(function()
        if videoPlayerView.isPlaying() then videoPlayerView.stopPlayback() end
    end)
    runUi(function()
        playButton.text = "Play"
        timeText.text = "00:00 / 00:00"
        seekBar.setProgress(0)
    end)
end

function extractVideoId(url)
    local patterns = {
        "v=([^&]+)",
        "youtu.be/([^?]+)",
        "embed/([^?]+)",
        "shorts/([^?]+)"
    }
    
    for _, pattern in ipairs(patterns) do
        local videoId = url:match(pattern)
        if videoId then
            return videoId
        end
    end
    
    return nil
end

function fetchYoutubeData(url, callback)
    local cleanUrl = url:match("^%s*(.-)%s*$")
    local encodedUrl = Uri.encode(cleanUrl)
    local videoId = extractVideoId(cleanUrl)
    
    if not videoId then
        callback(false, "Invalid YouTube URL")
        return
    end
    
    local api_url = "https://angelapis.my.id/ytdl?url=" .. encodedUrl

    Thread(JavaRunnable{
        run = function()
            Http.get(api_url, function(code, content)
                if code == 200 then
                    local status, json = pcall(cjson.decode, content)
                    if status and json then
                        if json.status == true and json.result then
                            local result = json.result
                            local title = result.title or "YouTube Video"
                            local duration = result.duration or 0
                            local videoFormats = {}
                            
                            if result.download_url and result.download_url ~= "" then
                                local video_url = result.download_url
                                local audio_url = result.download_url:gsub("video", "audio")
                                audio_url = audio_url:gsub("mp4", "mp3")
                                audio_url = audio_url:gsub("videoplayback", "audioplayback")
                                
                                if result.quality then
                                    table.insert(videoFormats, {
                                        type = "video",
                                        quality = result.quality,
                                        url = video_url,
                                        size = "Video"
                                    })
                                else
                                    table.insert(videoFormats, {
                                        type = "video",
                                        quality = "720p",
                                        url = video_url,
                                        size = "Video"
                                    })
                                end
                                
                                table.insert(videoFormats, {
                                    type = "audio",
                                    quality = "128kbps",
                                    url = audio_url,
                                    size = "Audio"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "video",
                                    quality = "480p",
                                    url = video_url,
                                    size = "Video"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "video",
                                    quality = "360p",
                                    url = video_url,
                                    size = "Video"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "audio",
                                    quality = "192kbps",
                                    url = audio_url,
                                    size = "Audio"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "audio",
                                    quality = "256kbps",
                                    url = audio_url,
                                    size = "Audio"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "video",
                                    quality = "1080p",
                                    url = video_url,
                                    size = "Video"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "video",
                                    quality = "240p",
                                    url = video_url,
                                    size = "Video"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "video",
                                    quality = "144p",
                                    url = video_url,
                                    size = "Video"
                                })
                                
                                table.insert(videoFormats, {
                                    type = "audio",
                                    quality = "320kbps",
                                    url = audio_url,
                                    size = "Audio"
                                })
                            end
                            
                            if #videoFormats > 0 then
                                callback(true, {
                                    title = title,
                                    duration = duration,
                                    data = videoFormats
                                })
                            else
                                callback(false, "No download URLs found")
                            end
                        else
                            callback(false, "API returned false status")
                        end
                    else
                        callback(false, "Invalid JSON response")
                    end
                else
                    callback(false, "HTTP Error: " .. code)
                end
            end)
        end
    }).start()
end

function cleanName(str)
    if not str or str == "" then 
        return "YouTube_" .. os.time() 
    end
    local s = str:gsub("[^a-zA-Z0-9%s%-_%.]", "")
    s = s:gsub("%s+", "_")
    return s:sub(1, 50)
end

function startDownload(url, title, format)
    pcall(function()
        local dm = activity.getSystemService(Context.DOWNLOAD_SERVICE)
        local request = DownloadManager.Request(Uri.parse(url))
        request.addRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        request.addRequestHeader("Accept", "*/*")
        request.addRequestHeader("Accept-Language", "en-US,en;q=0.9")
        request.addRequestHeader("Accept-Encoding", "identity")
        request.addRequestHeader("Connection", "keep-alive")
        request.addRequestHeader("Range", "bytes=0-")
        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        
        local fileExtension = (format == "Audio") and "mp3" or "mp4"
        local fileName = cleanName(title) .. "_" .. selectedQuality .. "." .. fileExtension
        
        local folderName = "YouTube Audio Video Downloader"
        local downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        local folderPath = File(downloadsDir, folderName)
        
        if not folderPath.exists() then
            folderPath.mkdirs()
        end
        
        local filePath = File(folderPath, fileName)
        request.setTitle(title .. " (" .. selectedFormat .. " - " .. selectedQuality .. ")")
        request.setDescription("Downloading from YouTube Audio Video Downloader")
        request.setDestinationUri(Uri.fromFile(filePath))
        request.setMimeType((format == "Audio") and "audio/mpeg" or "video/mp4")
        
        local downloadId = dm.enqueue(request)
        showToast("Download started: " .. fileName)
    end)
end

function showDownloadDialog()
    if not currentData or not currentData.data then
        showToast("No media data available.")
        return
    end
    
    local downloadDlg = LuaDialog(activity)
    downloadDlg.setTitle("Download Options")
    downloadDlg.setCancelable(true)
    
    local formatSpinner, qualitySpinner
    
    local downloadLayout = LinearLayout(activity)
    downloadLayout.setOrientation(LinearLayout.VERTICAL)
    downloadLayout.setPadding(30, 20, 30, 20)
    downloadLayout.setBackgroundColor(0xFF333333)
    
    local titleText = TextView(activity)
    titleText.setText("Choose Format and Quality")
    titleText.setTextSize(18)
    titleText.setTypeface(Typeface.DEFAULT_BOLD)
    titleText.setTextColor(0xFFFFFFFF)
    titleText.setGravity(Gravity.CENTER)
    titleText.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    titleText.setPadding(0, 0, 0, 20)
    downloadLayout.addView(titleText)
    
    local formatLabel = TextView(activity)
    formatLabel.setText("Format:")
    formatLabel.setTextColor(0xFFCCCCCC)
    formatLabel.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    formatLabel.setPadding(0, 10, 0, 5)
    downloadLayout.addView(formatLabel)
    
    formatSpinner = Spinner(activity)
    
    local availableFormats = {}
    local formatMap = {}
    
    for i, item in ipairs(currentData.data) do
        if not formatMap[item.type] then
            formatMap[item.type] = true
            local formatName = item.type:gsub("^%l", string.upper)
            table.insert(availableFormats, formatName)
        end
    end
    
    if #availableFormats == 0 then
        table.insert(availableFormats, "Video")
        table.insert(availableFormats, "Audio")
    end
    
    local formatAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, availableFormats)
    formatAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    formatSpinner.setAdapter(formatAdapter)
    formatSpinner.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    formatSpinner.setPadding(0, 0, 0, 15)
    downloadLayout.addView(formatSpinner)
    
    local qualityLabel = TextView(activity)
    qualityLabel.setText("Quality:")
    qualityLabel.setTextColor(0xFFCCCCCC)
    qualityLabel.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    qualityLabel.setPadding(0, 10, 0, 5)
    downloadLayout.addView(qualityLabel)
    
    qualitySpinner = Spinner(activity)
    
    local function updateQualitySpinner(format)
        local qualities = {}
        local qualityMap = {}
        
        for i, item in ipairs(currentData.data) do
            local itemType = item.type:gsub("^%l", string.upper)
            if itemType == format and item.quality and not qualityMap[item.quality] then
                qualityMap[item.quality] = true
                local qualityText = item.quality
                
                if format == "Video" then
                    if qualityText:find("1080") then
                        qualityText = "1080p HD"
                    elseif qualityText:find("720") then
                        qualityText = "720p HD"
                    elseif qualityText:find("480") then
                        qualityText = "480p SD"
                    elseif qualityText:find("360") then
                        qualityText = "360p SD"
                    elseif qualityText:find("240") then
                        qualityText = "240p Low"
                    elseif qualityText:find("144") then
                        qualityText = "144p Lowest"
                    else
                        qualityText = qualityText .. "p"
                    end
                else
                    if qualityText:find("320") then
                        qualityText = "320kbps High"
                    elseif qualityText:find("256") then
                        qualityText = "256kbps High"
                    elseif qualityText:find("192") then
                        qualityText = "192kbps Medium"
                    elseif qualityText:find("128") then
                        qualityText = "128kbps Medium"
                    elseif qualityText:find("64") then
                        qualityText = "64kbps Low"
                    else
                        qualityText = qualityText .. "kbps"
                    end
                end
                
                table.insert(qualities, qualityText)
            end
        end
        
        if #qualities == 0 then
            if format == "Video" then
                table.insert(qualities, "1080p HD")
                table.insert(qualities, "720p HD")
                table.insert(qualities, "480p SD")
                table.insert(qualities, "360p SD")
                table.insert(qualities, "240p Low")
                table.insert(qualities, "144p Lowest")
            else
                table.insert(qualities, "320kbps High")
                table.insert(qualities, "256kbps High")
                table.insert(qualities, "192kbps Medium")
                table.insert(qualities, "128kbps Medium")
                table.insert(qualities, "64kbps Low")
            end
        end
        
        local qualityAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, qualities)
        qualityAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        qualitySpinner.setAdapter(qualityAdapter)
        
        if #qualities > 0 then
            selectedQuality = qualities[1]:match("^[^%s]+")
        end
    end
    
    qualitySpinner.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    qualitySpinner.setPadding(0, 0, 0, 20)
    downloadLayout.addView(qualitySpinner)
    
    local buttonLayout = LinearLayout(activity)
    buttonLayout.setOrientation(LinearLayout.HORIZONTAL)
    buttonLayout.setLayoutParams(LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    ))
    
    local cancelButton = Button(activity)
    cancelButton.setText("Cancel")
    cancelButton.setLayoutParams(LinearLayout.LayoutParams(
        0,
        LinearLayout.LayoutParams.WRAP_CONTENT,
        1
    ))
    cancelButton.setPadding(0, 0, 5, 0)
    cancelButton.setOnClickListener{
        onClick = function(v)
            vibrator.vibrate(35)
            downloadDlg.dismiss()
        end
    }
    buttonLayout.addView(cancelButton)
    
    local downloadButton = Button(activity)
    downloadButton.setText("Download")
    downloadButton.setLayoutParams(LinearLayout.LayoutParams(
        0,
        LinearLayout.LayoutParams.WRAP_CONTENT,
        1
    ))
    downloadButton.setPadding(5, 0, 0, 0)
    downloadButton.setOnClickListener{
        onClick = function(v)
            vibrator.vibrate(35)
            
            local selectedFormatPos = formatSpinner.getSelectedItemPosition()
            local selectedQualityPos = qualitySpinner.getSelectedItemPosition()
            
            if selectedFormatPos >= 0 and selectedQualityPos >= 0 then
                selectedFormat = availableFormats[selectedFormatPos + 1]
                
                if qualitySpinner.getAdapter() then
                    local selectedItem = qualitySpinner.getAdapter().getItem(selectedQualityPos)
                    if selectedItem then
                        selectedQuality = tostring(selectedItem)
                        selectedQuality = selectedQuality:match("^[^%s]+")
                    end
                end
                
                local downloadUrl = nil
                for i, item in ipairs(currentData.data) do
                    local itemType = item.type:gsub("^%l", string.upper)
                    local itemQuality = item.quality or ""
                    
                    local normalizedItemQuality = itemQuality
                    if itemQuality:find("1080") or itemQuality:find("1080p") then
                        normalizedItemQuality = "1080p"
                    elseif itemQuality:find("720") or itemQuality:find("720p") then
                        normalizedItemQuality = "720p"
                    elseif itemQuality:find("480") or itemQuality:find("480p") then
                        normalizedItemQuality = "480p"
                    elseif itemQuality:find("360") or itemQuality:find("360p") then
                        normalizedItemQuality = "360p"
                    elseif itemQuality:find("240") or itemQuality:find("240p") then
                        normalizedItemQuality = "240p"
                    elseif itemQuality:find("144") or itemQuality:find("144p") then
                        normalizedItemQuality = "144p"
                    elseif itemQuality:find("320") then
                        normalizedItemQuality = "320kbps"
                    elseif itemQuality:find("256") then
                        normalizedItemQuality = "256kbps"
                    elseif itemQuality:find("192") then
                        normalizedItemQuality = "192kbps"
                    elseif itemQuality:find("128") then
                        normalizedItemQuality = "128kbps"
                    elseif itemQuality:find("64") then
                        normalizedItemQuality = "64kbps"
                    end
                    
                    local normalizedSelectedQuality = selectedQuality
                    if selectedQuality:find("1080") then
                        normalizedSelectedQuality = "1080p"
                    elseif selectedQuality:find("720") then
                        normalizedSelectedQuality = "720p"
                    elseif selectedQuality:find("480") then
                        normalizedSelectedQuality = "480p"
                    elseif selectedQuality:find("360") then
                        normalizedSelectedQuality = "360p"
                    elseif selectedQuality:find("240") then
                        normalizedSelectedQuality = "240p"
                    elseif selectedQuality:find("144") then
                        normalizedSelectedQuality = "144p"
                    elseif selectedQuality:find("320") then
                        normalizedSelectedQuality = "320kbps"
                    elseif selectedQuality:find("256") then
                        normalizedSelectedQuality = "256kbps"
                    elseif selectedQuality:find("192") then
                        normalizedSelectedQuality = "192kbps"
                    elseif selectedQuality:find("128") then
                        normalizedSelectedQuality = "128kbps"
                    elseif selectedQuality:find("64") then
                        normalizedSelectedQuality = "64kbps"
                    end
                    
                    if itemType == selectedFormat and (itemQuality == normalizedSelectedQuality or normalizedItemQuality == normalizedSelectedQuality) then
                        downloadUrl = item.url
                        break
                    end
                end
                
                if not downloadUrl and #currentData.data > 0 then
                    downloadUrl = currentData.data[1].url
                end
                
                if downloadUrl then
                    downloadDlg.dismiss()
                    
                    if service and service.speak then
                        service.speak("Starting download please wait")
                    end
                    
                    startDownload(downloadUrl, currentData.title, selectedFormat)
                else
                    showToast("No download link found for selected quality.")
                end
            else
                showToast("Please select format and quality.")
            end
        end
    }
    buttonLayout.addView(downloadButton)
    
    downloadLayout.addView(buttonLayout)
    
    formatSpinner.setOnItemSelectedListener{
        onItemSelected = function(parent, view, position, id)
            vibrator.vibrate(20)
            local selectedFmt = availableFormats[position + 1]
            selectedFormat = selectedFmt
            updateQualitySpinner(selectedFmt)
        end
    }
    
    qualitySpinner.setOnItemSelectedListener{
        onItemSelected = function(parent, view, position, id)
            vibrator.vibrate(20)
            if qualitySpinner.getAdapter() and position >= 0 then
                local selectedItem = qualitySpinner.getAdapter().getItem(position)
                if selectedItem then
                    selectedQuality = tostring(selectedItem)
                    selectedQuality = selectedQuality:match("^[^%s]+")
                end
            end
        end
    }
    
    updateQualitySpinner(availableFormats[1] or "Video")
    downloadDlg.setView(downloadLayout)
    downloadDlg.show()
end

function playInternal(url)
    stopAllMedia()
    
    videoPlayerView.setVisibility(View.VISIBLE)
    resultText.setVisibility(View.GONE)

    pcall(function()
        videoPlayerView.setVideoURI(Uri.parse(url))
        videoPlayerView.requestFocus()
        videoPlayerView.setOnPreparedListener(MediaPlayer.OnPreparedListener{
            onPrepared = function(mp)
                playButton.text = "Pause"
                videoPlayerView.start()
                startUpdateTime()
                showToast("Playing Video...")
            end
        })
        videoPlayerView.setOnCompletionListener(MediaPlayer.OnCompletionListener{
            onCompletion = function(mp)
                playButton.text = "Play"
                stopUpdateTime()
            end
        })
        videoPlayerView.setOnErrorListener(MediaPlayer.OnErrorListener{
            onError = function(mp, what, extra)
                showToast("Playback error")
                playButton.text = "Play"
                return true
            end
        })
    end)
end

layout = {
    ScrollView,
    layout_width = "fill",
    layout_height = "fill",
    {
        LinearLayout,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "wrap",
        padding = "16dp",
        backgroundColor = "#FAFAFA",
        {
            TextView,
            id = "appTitle",
            text = "Developer: Sabir Jamil",
            textSize = "20sp",
            textColor = "#FF0000",
            gravity = "center",
            paddingBottom = "10dp",
        },
        {
            EditText,
            id = "urlInput",
            hint = "Paste YouTube URL here...",
            layout_width = "fill",
            layout_height = "wrap_content",
            textSize = "14sp",
            padding = "10dp",
        },
        {
            Button,
            id = "processButton",
            text = "Process Link",
            layout_width = "fill",
            layout_height = "wrap_content",
            backgroundColor = "#FF0000",
            textColor = "#FFFFFF",
            layout_marginTop = "10dp",
        },
        {
            LinearLayout,
            orientation = "vertical",
            layout_width = "fill",
            layout_height = "wrap",
            layout_marginTop = "10dp",
            backgroundColor = "#000000",
            gravity = "center",
            {
                VideoView,
                id = "videoPlayerView",
                layout_width = "fill",
                layout_height = "250dp",
                visibility = View.GONE,
            },
            {
                TextView,
                id = "resultText",
                text = "Paste YouTube URL and click Process Link",
                textColor = "#FFFFFF",
                gravity = "center",
                padding = "10dp",
                textSize = "14sp",
            },
        },
        {
            LinearLayout,
            orientation = "vertical",
            layout_width = "fill",
            padding = "5dp",
            backgroundColor = "#212121",
            {
                TextView,
                id = "timeText",
                text = "00:00 / 00:00",
                textColor = "#FFFFFF",
                gravity = "center",
                padding = "5dp",
                textSize = "12sp",
            },
            {
                SeekBar,
                id = "seekBar",
                layout_width = "fill",
                layout_height = "wrap_content",
                padding = "10dp",
            },
        },
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            paddingTop = "10dp",
            {
                Button,
                id = "playButton",
                text = "Play",
                layout_width = "fill",
                layout_weight = 1,
                enabled = false,
                backgroundColor = "#2196F3",
                textColor = "#FFFFFF",
            },
            {
                Button,
                id = "downloadButton",
                text = "Download",
                layout_width = "fill",
                layout_weight = 1,
                enabled = false,
                backgroundColor = "#4CAF50",
                textColor = "#FFFFFF",
            },
        },
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            layout_marginTop = "10dp",
            {
                Button,
                id = "aboutButton",
                text = "About",
                layout_width = "fill",
                layout_weight = 1,
                backgroundColor = "#FF9800",
                textColor = "#FFFFFF",
            },
            {
                Button,
                id = "updateButton",
                text = "New Update Available",
                layout_width = "fill",
                layout_weight = 1,
                backgroundColor = "#FF5722",
                textColor = "#FFFFFF",
                visibility = View.GONE,
            },
            {
                Button,
                id = "exitButton",
                text = "Exit",
                layout_width = "fill",
                layout_weight = 1,
                backgroundColor = "#F44336",
                textColor = "#FFFFFF",
            },
        },
    }
}

dlg = LuaDialog(this)
dlg.setTitle("YouTube Audio Video Downloader")
dlg.setView(loadlayout(layout))
appTitle.setTypeface(Typeface.DEFAULT_BOLD)

updateButton.onClick = function()
    vibrator.vibrate(40)
    showUpdateButtonDialog()
end

processButton.onClick = function()
    local url = urlInput.getText().toString()
    if url == "" then 
        showToast("Please enter YouTube URL first!") 
        return 
    end
    
    if isProcessing then return end
    isProcessing = true
    
    if service and service.speak then
        service.speak("Processing please wait")
    end
    
    processButton.text = "Processing..."
    processButton.setEnabled(false)
    resultText.text = "Processing YouTube link...\nPlease wait"
    playButton.setEnabled(false)
    downloadButton.setEnabled(false)
    stopAllMedia()
    
    fetchYoutubeData(url, function(success, data)
        isProcessing = false
        runUi(function()
            if success then
                currentData = data
                local formatsCount = #data.data
                local videoCount = 0
                local audioCount = 0
                
                for i, item in ipairs(data.data) do
                    if item.type == "video" then
                        videoCount = videoCount + 1
                    elseif item.type == "audio" then
                        audioCount = audioCount + 1
                    end
                end
                
                local minutes = math.floor(data.duration / 60)
                local seconds = data.duration % 60
                local durationText = string.format("%02d:%02d", minutes, seconds)
                
                resultText.text = "✓ Media Ready!\n\nTitle: " .. data.title .. 
                                "\nDuration: " .. durationText ..
                                "\nFormats: " .. formatsCount .. " available" ..
                                "\nVideo: " .. videoCount .. " | Audio: " .. audioCount ..
                                "\n\nTap Play to preview or Download to save"
                playButton.setEnabled(true)
                downloadButton.setEnabled(true)
                showToast("Media ready! " .. formatsCount .. " formats available")
            else
                resultText.text = "✗ Error: " .. tostring(data)
                playButton.setEnabled(false)
                downloadButton.setEnabled(false)
                showToast("Processing failed: " .. tostring(data))
            end
            processButton.text = "Process Link"
            processButton.setEnabled(true)
        end)
    end)
end

playButton.onClick = function()
    if not currentData or not currentData.data or #currentData.data == 0 then 
        showToast("No media loaded!")
        return 
    end
    
    if service and service.speak then
        service.speak("Playing please wait")
    end
    
    vibrator.vibrate(30)
    
    if videoPlayerView.isPlaying() then
        videoPlayerView.pause()
        playButton.text = "Play"
        stopUpdateTime()
        showToast("Paused")
    else
        if videoPlayerView.getDuration() > 0 then
            videoPlayerView.start()
            playButton.text = "Pause"
            startUpdateTime()
            showToast("Playing...")
        else
            local videoUrl = nil
            for i, item in ipairs(currentData.data) do
                if item.type == "video" then
                    videoUrl = item.url
                    break
                end
            end
            
            if not videoUrl and #currentData.data > 0 then
                videoUrl = currentData.data[1].url
            end
            
            if videoUrl then
                playInternal(videoUrl)
            else
                showToast("No playable URL found")
            end
        end
    end
end

downloadButton.onClick = function()
    if currentData then
        vibrator.vibrate(50)
        showDownloadDialog()
    else
        showToast("No media to download!")
    end
end

aboutButton.onClick = function()
    local about_views = {}
    local about_layout = {
        LinearLayout;
        orientation = "vertical";
        padding = "16dp";
        layout_width = "fill";
        layout_height = "wrap";
        {
            TextView;
            text = "YouTube Audio Video Downloader - Version 1.0\n\nA professional YouTube media player & downloader with premium features.\n\nMAIN FEATURES:\n• Direct YouTube Video Playback\n• MP4 Video & MP3 Audio Downloads\n• Multiple Quality Options (HD/SD)\n• Built-in Media Player\n• Auto-Update System\n• Smart File Organization\n\nAUTO-UPDATE SYSTEM:\n✓ Automatically checks for updates\n✓ One-click installation\n✓ Update notifications\n✓ Safe backup & restore\n\nAvailable Qualities:\nVideo: 1080p HD, 720p HD, 480p SD, 360p SD, 240p Low, 144p Lowest\nAudio: 320kbps High, 256kbps High, 192kbps Medium, 128kbps Medium\n\nFiles save to: Download/YouTube Audio Video Downloader/";
            textColor = "#666666";
            textSize = 14;
            paddingBottom = "20dp";
        };
        {
            TextView;
            text = "Join Our Community For More Useful Tools, Contact us for feedback and suggestions, and stay updated with our latest tools";
            textSize = 16;
            gravity = "center";
            textColor = "#2E7D32";
            paddingTop = "20dp";
            paddingBottom = "20dp";
        };
        {
            LinearLayout;
            orientation = "horizontal";
            layout_width = "fill";
            layout_height = "wrap_content";
            gravity = "center";
            layout_marginTop = "5dp";
            {
                Button;
                id = "joinWhatsAppGroupButton";
                text = "JOIN WHATSAPP GROUP";
                layout_width = "0dp";
                layout_height = "wrap_content";
                layout_weight = "1";
                layout_margin = "1dp";
                textSize = "10sp";
                padding = "6dp";
                backgroundColor = "#25D366";
                textColor = "#FFFFFF";
            };
            {
                Button;
                id = "joinYouTubeChannelButton";
                text = "JOIN YOUTUBE CHANNEL";
                layout_width = "0dp";
                layout_height = "wrap_content";
                layout_weight = "1";
                layout_margin = "1dp";
                textSize = "10sp";
                padding = "6dp";
                backgroundColor = "#FF0000";
                textColor = "#FFFFFF";
            };
            {
                Button;
                id = "joinTelegramChannelButton";
                text = "JOIN TELEGRAM CHANNEL";
                layout_width = "0dp";
                layout_height = "wrap_content";
                layout_weight = "1";
                layout_margin = "1dp";
                textSize = "10sp";
                padding = "6dp";
                backgroundColor = "#2196F3";
                textColor = "#FFFFFF";
            };
            {
                Button;
                id = "goBackButton";
                text = "GO BACK";
                layout_width = "0dp";
                layout_height = "wrap_content";
                layout_weight = "1";
                layout_margin = "1dp";
                textSize = "10sp";
                padding = "6dp";
                backgroundColor = "#9E9E9E";
                textColor = "#FFFFFF";
            };
        }
    }
    
    local about_dialog = LuaDialog(activity)
    about_dialog.setTitle("Developer: Sabir Jamil")
    about_dialog.setView(loadlayout(about_layout, about_views))
    
    about_views.joinWhatsAppGroupButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            
            local success, errorMsg = pcall(function()
                local message = "Assalam%20o%20Alaikum.%20I%20hope%20you%20are%20doing%20well.%20I%20would%20like%20to%20join%20your%20WhatsApp%20group.%20Kindly%20share%20the%20instructions.%20group%20rules%20and%20regulations.%20Thank%20you.%20so%20much"
                local url = "https://wa.me/923486623399?text=" .. message
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                activity.startActivity(intent)
            end)
            
            if not success then
                showToast("Could not open WhatsApp")
            end
        end
        
        if service and service.speak then
            service.speak("Opening WhatsApp Group")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 1000)
        else
            performActions()
        end
    end
    
    about_views.joinYouTubeChannelButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            
            local success, errorMsg = pcall(function()
                local url = "https://www.youtube.com/@TechForVI"
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                activity.startActivity(intent)
            end)
            
            if not success then
                showToast("Could not open YouTube")
            end
        end
        
        if service and service.speak then
            service.speak("Opening YouTube Channel")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 1000)
        else
            performActions()
        end
    end
    
    about_views.joinTelegramChannelButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            
            local success, errorMsg = pcall(function()
                local url = "https://t.me/TechForVI"
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                activity.startActivity(intent)
            end)
            
            if not success then
                showToast("Could not open Telegram")
            end
        end
        
        if service and service.speak then
            service.speak("Opening Telegram Channel")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 1000)
        else
            performActions()
        end
    end
    
    about_views.goBackButton.onClick = function()
        about_dialog.dismiss()
    end
    
    about_dialog.show()
end

seekBar.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener{
    onProgressChanged = function(sb, progress, fromUser)
        if fromUser then
            local currentMinutes = math.floor(progress / 60000)
            local currentSeconds = math.floor((progress % 60000) / 1000)
            local currentStr = string.format("%02d:%02d", currentMinutes, currentSeconds)
            local totalStr = string.match(timeText.text, "/%s*(.*)") or "00:00"
            timeText.text = currentStr .. " / " .. totalStr
        end
    end,
    onStartTrackingTouch = function(sb)
        stopUpdateTime()
    end,
    onStopTrackingTouch = function(sb)
        vibrator.vibrate(20)
        local newPosition = sb.getProgress()
        if videoPlayerView then
            videoPlayerView.seekTo(newPosition)
        end
        startUpdateTime()
    end
})

exitButton.onClick = function()
    stopAllMedia()
    dlg.dismiss()
end

dlg.show()