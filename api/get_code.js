const axios = require('axios');

export default async function handler(req, res) {
  // آپ کی فائل کا RAW لنک
  const github_raw_url = "https://raw.githubusercontent.com/TechForVI/YouTube-Audio-Video-Downloader/main/youtube.lua";

  try {
    const response = await axios.get(github_raw_url);
    
    // سیکیورٹی کے لیے Content-Type سیٹ کریں
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store'); // تاکہ کوڈ پرانا لوڈ نہ ہو
    
    res.status(200).send(response.data);
  } catch (error) {
    res.status(500).send("-- Error: Could not fetch code from GitHub");
  }
}