require "import"
import "android.widget.*"
import "android.view.View"
import "android.content.Context"
import "android.text.InputType"
import "cjson"
import "android.content.Intent"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.widget.VideoView"
import "android.widget.MediaController"
import "java.util.HashMap"
import "java.net.URLEncoder"
import "android.app.DownloadManager"
import "android.os.Environment"
import "android.graphics.Typeface"
import "android.view.Gravity"
import "android.graphics.drawable.ColorDrawable"
import "java.io.File"

activity = this

local CURRENT_VERSION = "1.5"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/TechForVI/TikTok-Audio-Video-Downloader/main/"
local VERSION_URL = GITHUB_RAW_URL .. "version.txt"
local SCRIPT_URL = GITHUB_RAW_URL .. "main.lua"
local PLUGIN_PATH = "/sdcard/解说/Plugins/TikTok Audio Video Downloader/main.lua"

local updateInProgress = false
local updateDlg = nil

function checkUpdate()
    if updateInProgress then return end
    
    Http.get(VERSION_URL, function(code, onlineVersion)
        if code == 200 and onlineVersion then
            onlineVersion = tostring(onlineVersion):match("^%s*(.-)%s*$")
            if onlineVersion and onlineVersion ~= CURRENT_VERSION then
                showUpdateDialog(onlineVersion)
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
        service.speak("Downloading update, please wait...")
        downloadAndInstallUpdate()
    end)
    
    updateDlg.setButton2("Later", function()
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
                        
                        local successDialog = LuaDialog(activity)
                        successDialog.setTitle("Update Successful")
                        successDialog.setMessage("Please restart the plugin.")
                        successDialog.setButton("OK", function()
                            successDialog.dismiss()
                            service.speak("Update successful. Please restart plugin.")
                            
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
                            if restored then
                                service.speak("Update failed, old version restored.")
                            else
                                service.speak("Update failed, please try again.")
                            end
                        end)
                        errorDialog.show()
                    end
                else
                    local errorDialog = LuaDialog(activity)
                    errorDialog.setTitle("Update Failed")
                    errorDialog.setMessage("Cannot write temporary file.")
                    errorDialog.setButton("OK", function()
                        errorDialog.dismiss()
                        service.speak("Update failed, cannot write file.")
                    end)
                    errorDialog.show()
                end
            else
                local errorDialog = LuaDialog(activity)
                errorDialog.setTitle("Update Failed")
                errorDialog.setMessage("Cannot download new script.")
                errorDialog.setButton("OK", function()
                    errorDialog.dismiss()
                    service.speak("Update failed, download error.")
                end)
                errorDialog.show()
            end
            updateInProgress = false
        end)
    end
    
    local handler = luajava.bindClass("android.os.Handler")(activity.getMainLooper())
    handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
        run = performUpdate
    }), 500)
end

checkUpdate()

local SOCIAL_DOWNLOADER_API = "https://all-in-one-downloader.anggelaimut27.workers.dev/"

local videoOptions = {}
local selectedUrl = nil
local trackTitle = "Media_Download"
local selectedItemData = nil 

local selectedFormat = "Video"
local selectedQuality = "720p"

function vibrate()
    local vibrator = activity.getSystemService(Context.VIBRATOR_SERVICE)
    if vibrator then vibrator.vibrate(35) end
end

function urlEncode(str)
    if str then return URLEncoder.encode(str, "UTF-8") end
    return ""
end

function cleanName(str)
    if not str or str == "" then 
        return "Media_" .. os.time() 
    end
    local s = str:gsub("[^a-zA-Z0-9%s%-_%.]", "")
    s = s:gsub("%s+", "_")
    return s:sub(1, 50)
end

function startDownload(url, title, format)
    pcall(function()
        local DownloadManager = luajava.bindClass("android.app.DownloadManager")
        local dm = activity.getSystemService(Context.DOWNLOAD_SERVICE)
        local request = DownloadManager.Request(Uri.parse(url))
        request.addRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
        request.setNotificationVisibility(1)
        
        local fileExtension = (format == "Audio") and "mp3" or "mp4"
        local fileName = cleanName(title) .. "_" .. selectedQuality .. "." .. fileExtension
        request.setTitle(title .. " (" .. selectedFormat .. " - " .. selectedQuality .. ")")
        request.setDescription("Downloading from Social Downloader Pro")
        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "SocialDownloader/" .. fileName)
        
        dm.enqueue(request)
        service.speak("Download started: " .. fileName)
    end)
end

function showDownloadDialog()
    if not selectedItemData then
        service.speak("No media data available.")
        return
    end
    
    local downloadDlg = LuaDialog(activity)
    downloadDlg.setTitle("Download Options")
    downloadDlg.setCancelable(true)
    
    local formatSpinner, qualitySpinner
    
    local downloadLayout = LinearLayout(activity)
    downloadLayout.setOrientation(LinearLayout.VERTICAL)
    downloadLayout.setPadding(30, 20, 30, 20)
    
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
    
    for i, item in ipairs(selectedItemData.data or {}) do
        local formatName = item.type:gsub("^%l", string.upper)
        if not formatMap[formatName] then
            formatMap[formatName] = true
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
    
    local initialQualities = {}
    for i, item in ipairs(selectedItemData.data or {}) do
        if item.type == "video" and item.quality then
            local qualityName = item.quality:gsub("_", " "):gsub("^%l", string.upper)
            table.insert(initialQualities, qualityName)
        end
    end
    
    if #initialQualities == 0 then
        table.insert(initialQualities, "HD No Watermark")
        table.insert(initialQualities, "No Watermark")
        table.insert(initialQualities, "With Watermark")
    end
    
    local qualityAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, initialQualities)
    qualityAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    qualitySpinner.setAdapter(qualityAdapter)
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
            vibrate()
            downloadDlg.dismiss()
            service.speak("Download cancelled.")
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
            vibrate()
            
            local selectedFormatPos = formatSpinner.getSelectedItemPosition()
            local selectedQualityPos = qualitySpinner.getSelectedItemPosition()
            
            if selectedFormatPos >= 0 and selectedQualityPos >= 0 then
                local chosenFormat = availableFormats[selectedFormatPos + 1]
                local chosenQuality = initialQualities[selectedQualityPos + 1]
                
                local downloadUrl = nil
                for i, item in ipairs(selectedItemData.data or {}) do
                    local itemFormat = item.type:gsub("^%l", string.upper)
                    local itemQuality = item.quality:gsub("_", " "):gsub("^%l", string.upper)
                    
                    if itemFormat == chosenFormat and itemQuality == chosenQuality then
                        downloadUrl = item.url
                        selectedFormat = itemFormat
                        selectedQuality = itemQuality
                        break
                    end
                end
                
                if not downloadUrl and #selectedItemData.data > 0 then
                    downloadUrl = selectedItemData.data[1].url
                    selectedFormat = selectedItemData.data[1].type:gsub("^%l", string.upper)
                    selectedQuality = selectedItemData.data[1].quality or "Default"
                end
                
                if downloadUrl then
                    downloadDlg.dismiss()
                    startDownload(downloadUrl, trackTitle, selectedFormat)
                else
                    service.speak("No download link found.")
                end
            else
                service.speak("Please select format and quality.")
            end
        end
    }
    buttonLayout.addView(downloadButton)
    
    downloadLayout.addView(buttonLayout)
    
    local function updateQualitySpinner(format)
        local qualities = {}
        
        for i, item in ipairs(selectedItemData.data or {}) do
            local itemFormat = item.type:gsub("^%l", string.upper)
            if itemFormat == format and item.quality then
                local qualityName = item.quality:gsub("_", " "):gsub("^%l", string.upper)
                table.insert(qualities, qualityName)
            end
        end
        
        if #qualities == 0 then
            if format == "Video" then
                table.insert(qualities, "HD Quality")
                table.insert(qualities, "Standard Quality")
                table.insert(qualities, "Low Quality")
            else
                table.insert(qualities, "High Quality")
                table.insert(qualities, "Medium Quality")
                table.insert(qualities, "Low Quality")
            end
        end
        
        local newAdapter = ArrayAdapter(activity, android.R.layout.simple_spinner_item, qualities)
        newAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        qualitySpinner.setAdapter(newAdapter)
    end
    
    formatSpinner.setOnItemSelectedListener{
        onItemSelected = function(parent, view, position, id)
            vibrate()
            local selectedFmt = availableFormats[position + 1]
            updateQualitySpinner(selectedFmt)
            selectedFormat = selectedFmt
        end
    }
    
    qualitySpinner.setOnItemSelectedListener{
        onItemSelected = function(parent, view, position, id)
            vibrate()
            local qualities = {}
            for i, item in ipairs(selectedItemData.data or {}) do
                local itemFormat = item.type:gsub("^%l", string.upper)
                if itemFormat == selectedFormat and item.quality then
                    local qualityName = item.quality:gsub("_", " "):gsub("^%l", string.upper)
                    table.insert(qualities, qualityName)
                end
            end
            
            if position >= 0 and position < #qualities then
                selectedQuality = qualities[position + 1]
            end
        end
    }
    
    updateQualitySpinner(availableFormats[1] or "Video")
    downloadDlg.setView(downloadLayout)
    downloadDlg.show()
end

local item_layout = {
    LinearLayout,
    orientation="vertical",
    layout_width="fill",
    layout_height="wrap_content",
    padding="8dp",
    {
        LinearLayout,
        orientation="vertical",
        layout_width="fill",
        layout_height="wrap_content",
        backgroundColor=0xFF333333,
        padding="15dp",
        {
            TextView,
            id="opt_res",
            textSize="18sp",
            typeface=Typeface.DEFAULT_BOLD,
            textColor=0xFFFFFFFF,
        },
        {
            TextView,
            id="opt_size",
            textSize="14sp",
            textColor=0xFFCCCCCC,
            layout_marginTop="5dp"
        }
    }
}

layout = {
    LinearLayout,
    orientation = "vertical",
    layout_width = "fill",
    layout_height = "fill",
    padding = "10dp",
    {
        TextView,
        text = "Developer: i love babu",
        textColor = 0xFFBB86FC,
        textSize = "14sp",
        layout_marginTop = "2dp",
        layout_marginBottom = "5dp",
        paddingLeft = "5dp"
    },
    {
        EditText,
        id = "textInput",
        hint = "Paste Link Here...",
        layout_width = "fill",
        layout_height = "wrap_content",
        padding = "10dp",
        lines = 1,
        inputType = InputType.TYPE_CLASS_TEXT,
    },
    {
        Button,
        id = "scanButton",
        text = "Process Link",
        layout_width = "fill",
        layout_height = "wrap_content",
        layout_marginTop = "5dp"
    },
    {
        FrameLayout,
        layout_width = "fill",
        layout_height = "200dp",
        layout_marginTop = "10dp",
        backgroundColor = "0xFF000000",
        {
            VideoView,
            id = "videoDisplay",
            layout_width = "match",
            layout_height = "match",
            layout_gravity = "center",
            visibility = View.GONE
        },
        {
            TextView,
            id = "statusText",
            text = "Paste link and click Process.",
            textColor = "0xFF888888",
            layout_gravity = "center",
            visibility = View.VISIBLE,
            gravity = "center",
            padding="10dp"
        }
    },
    {
        TextView,
        id="listLabel",
        text = "Multiple options found:",
        textColor = 0xFFCCCCCC,
        layout_marginTop = "10dp",
        paddingLeft = "5dp",
        visibility = "gone"
    },
    {
        ListView,
        id = "optionsList",
        layout_width = "fill",
        layout_height = "0dp",
        layout_weight = 1,
        dividerHeight = "0",
        visibility = "gone"
    },
    {
        LinearLayout,
        id="finalInfoLayout",
        orientation="vertical",
        layout_width="fill",
        layout_height="0dp",
        layout_weight=1,
        padding="10dp",
        visibility="gone",
        gravity="center",
        {
            TextView,
            text="✅ Direct Link Found",
            textSize="20sp",
            textColor=0xFF00FF00,
            typeface=Typeface.DEFAULT_BOLD,
            gravity="center"
        },
        {
            TextView,
            id="finalTitleText",
            text="Media Ready",
            textSize="16sp",
            textColor=0xFFFFFFFF,
            gravity="center",
            layout_marginTop="10dp"
        },
        {
            TextView,
            id="finalDetailText",
            text="Tap Play or Download",
            textSize="14sp",
            textColor=0xFFAAAAAA,
            gravity="center",
            layout_marginTop="5dp"
        },
        {
            Button,
            id="backToListBtn",
            text = "Back to List",
            layout_marginTop="20dp",
            visibility="gone",
            onClick=function()
                finalInfoLayout.setVisibility(View.GONE)
                optionsList.setVisibility(View.VISIBLE)
                listLabel.setVisibility(View.VISIBLE)
                playButton.setEnabled(false)
                downloadButton.setEnabled(false)
            end
        }
    },
    {
        LinearLayout,
        orientation = "horizontal",
        layout_width = "fill",
        layout_height = "wrap_content",
        layout_marginTop = "5dp",
        {
            Button,
            id = "playButton",
            text = "Play",
            layout_width = "0dp",
            layout_weight = 1,
            enabled = false
        },
        {
            Button,
            id = "downloadButton",
            text = "Download",
            layout_width = "0dp",
            layout_weight = 1,
            enabled = false,
            onClick = function() 
                vibrate() 
                showDownloadDialog() 
            end
        }
    },
    {
        LinearLayout,
        orientation = "horizontal",
        layout_width = "fill",
        layout_height = "wrap_content",
        layout_marginTop = "10dp",
        {
            Button,
            text = "About", 
            layout_width = "0dp",
            layout_weight = 1,
            onClick = function() 
                vibrate()
                aboutButton.onClick()
            end 
        },
        {
            Button,
            text = "Exit", 
            layout_width = "0dp",
            layout_weight = 1,
            onClick = function()
                videoDisplay.stopPlayback()
                dlg.dismiss()
            end
        }
    }
}

dlg = LuaDialog(this)
dlg.setTitle("TikTok Audio Video Downloader") 
dlg.setView(loadlayout(layout))
dlg.setCancelable(false)

function updateStatus(txt)
    statusText.text = txt
    statusText.setVisibility(View.VISIBLE)
    videoDisplay.setVisibility(View.GONE)
    service.speak(txt)
end

function resetUI()
    videoOptions = {}
    playButton.setEnabled(false)
    downloadButton.setEnabled(false)
    videoDisplay.stopPlayback()
    optionsList.setAdapter(nil)
    
    optionsList.setVisibility(View.GONE)
    listLabel.setVisibility(View.GONE)
    finalInfoLayout.setVisibility(View.GONE)
    backToListBtn.setVisibility(View.GONE)
end

function showFinalPanel(itemData, title, fromList)
    selectedItemData = itemData
    if itemData.data and #itemData.data > 0 then
        selectedUrl = itemData.data[1].url
    end
    
    finalTitleText.text = title or itemData.title or "Media Found"
    finalDetailText.text = "Ready to Stream/Save"
    trackTitle = itemData.title or title or "Media"
    
    optionsList.setVisibility(View.GONE)
    listLabel.setVisibility(View.GONE)
    finalInfoLayout.setVisibility(View.VISIBLE)
    
    if fromList then
        backToListBtn.setVisibility(View.VISIBLE)
    else
        backToListBtn.setVisibility(View.GONE)
    end
    
    playButton.setEnabled(true)
    downloadButton.setEnabled(true)
    updateStatus("Media Ready.")
end

function validateUrl(url)
    if not url then return false end
    local pattern = "^https?://[%w-_%.%?%.:/%+=&]+$"
    return string.match(url, pattern) ~= nil
end

scanButton.onClick = function()
    vibrate()
    local input_url = tostring(textInput.text):match("^%s*(.-)%s*$")
    if #input_url == 0 or not validateUrl(input_url) then
        updateStatus("Invalid URL. Please check the link.")
        return
    end
    
    resetUI()
    updateStatus("Processing...")
    
    local target_url = string.format("%s?url=%s", SOCIAL_DOWNLOADER_API, urlEncode(input_url))
    
    Thread(Runnable {
        run = function()
            Http.get(target_url, function(code, content)
                if code ~= 200 then updateStatus("HTTP Error: " .. code) return end
                
                local status, jsonData = pcall(cjson.decode, content)
                if not status then updateStatus("JSON Parse Error") return end
                
                if jsonData.status == true then
                    trackTitle = jsonData.title or "Social_Media_" .. os.time()
                    videoOptions = {}
                    if jsonData.data and #jsonData.data > 0 then
                        for i, item in ipairs(jsonData.data) do
                            local qualityName = item.quality or item.type
                            local displayName = item.type:gsub("^%l", string.upper) .. " - " .. 
                                               qualityName:gsub("_", " "):gsub("^%l", string.upper)
                            
                            table.insert(videoOptions, {
                                name = displayName,
                                url = item.url,
                                data = jsonData,
                                index = i
                            })
                        end
                        updateStatus("Found " .. #jsonData.data .. " options.")
                        showFinalPanel(jsonData, "Media Ready", false)
                        service.speak("Link processed successfully.")
                    else
                        updateStatus("No download links found.")
                    end
                else
                    updateStatus("API Failed: " .. tostring(jsonData.message or "Unknown error"))
                end
            end)
        end
    }).start()
end

optionsList.onItemClick = function(parent, view, position, id)
    vibrate()
    local selected = videoOptions[position + 1]
    if selected then
        showFinalPanel(selected.data, selected.name, true)
    end
end

playButton.onClick = function()
    vibrate()
    if not selectedUrl then return end
    
    if videoDisplay.isPlaying() then
        videoDisplay.pause()
        playButton.text = "Resume"
    else
        statusText.setVisibility(View.GONE)
        videoDisplay.setVisibility(View.VISIBLE)
        local mc = MediaController(activity)
        videoDisplay.setMediaController(mc)
        videoDisplay.setVideoURI(Uri.parse(selectedUrl))
        videoDisplay.setOnPreparedListener(MediaPlayer.OnPreparedListener{
            onPrepared = function(mp)
                videoDisplay.start()
                playButton.text = "Pause"
                service.speak("Playing.")
            end
        })
    end
end

aboutButton = {}
aboutButton.onClick = function()
    vibrate()
    local about_views = {}
    local about_layout = {
        LinearLayout;
        orientation = "vertical";
        padding = "16dp";
        layout_width = "fill";
        layout_height = "wrap";
        {
            TextView;
            text = "TikTok Audio Video Downloader";
            textColor = "#333333";
            textSize = 18;
            gravity = "center";
            paddingBottom = "10dp";
        };
        {
            TextView;
            text = "TikTok Audio Video Downloader is a professional plugin that allows you to download media from various platforms including TikTok. Key features include:\n\n• Download TikTok videos in audio and video format\n• Download options in different qualities (720p, 1080p, etc.)\n• Download videos without watermark\n• Download live videos and stories\n• Play and download options\n• User-friendly interface\n• Fast link processing\n• Quality and format options\n\nThis is a complete media downloader that works best for TikTok.";
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
    
    local about_dialog = LuaDialog(this)
    about_dialog.setTitle("About")
    about_dialog.setView(loadlayout(about_layout, about_views))
    
    about_views.joinWhatsAppGroupButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            pcall(function()
                local url = "https://wa.me/923486623399?text=Assalam%20o%20Alaikum%2C%20I%20Want%20to%20Join%20Tech%20For%20V%20I%20WhatsApp%20Group%2C%20Kindly%20Add%20Me%20in%20Tech%20For%20V%20I%20WhatsApp%20Group%2C%20As%20Soon%20As%20Possible%20Thanks"
                local intent = Intent(Intent.ACTION_VIEW)
                intent.setData(Uri.parse(url))
                this.startActivity(intent)
            end)
        end
        
        if service and service.speak then
            service.speak("Opening WhatsApp Group")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 500)
        else
            performActions()
        end
    end
    
    about_views.joinYouTubeChannelButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            pcall(function()
                local url = "https://youtube.com/@techforvi"
                local intent = Intent(Intent.ACTION_VIEW)
                intent.setData(Uri.parse(url))
                this.startActivity(intent)
            end)
        end
        
        if service and service.speak then
            service.speak("Opening YouTube Channel")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 500)
        else
            performActions()
        end
    end
    
    about_views.joinTelegramChannelButton.onClick = function()
        local function performActions()
            about_dialog.dismiss()
            dlg.dismiss()
            pcall(function()
                local url = "https://t.me/TechForVI"
                local intent = Intent(Intent.ACTION_VIEW)
                intent.setData(Uri.parse(url))
                this.startActivity(intent)
            end)
        end
        
        if service and service.speak then
            service.speak("Opening Telegram Channel")
            local handler = luajava.bindClass("android.os.Handler")()
            handler.postDelayed(luajava.createProxy("java.lang.Runnable", {
                run = performActions
            }), 500)
        else
            performActions()
        end
    end
    
    about_views.goBackButton.onClick = function()
        about_dialog.dismiss()
    end
    
    about_dialog.show()
end

service.playSoundTick()
dlg.show()