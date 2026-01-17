const https = require('https');

export default function handler(req, res) {
    const url = "https://raw.githubusercontent.com/TechForVI/YouTube-Audio-Video-Downloader/main/youtube.lua";

    https.get(url, (response) => {
        let data = '';
        response.on('data', (chunk) => { data += chunk; });
        response.on('end', () => {
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.setHeader('Cache-Control', 'no-store');
            res.status(200).send(data);
        });
    }).on('error', (err) => {
        res.status(500).send("Error: " + err.message);
    });
}