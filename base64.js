const fs = require('fs');

// 秘密鍵をファイルから読み込む
const privateKey = fs.readFileSync('C:/Users/tokyo/Videos/private_key.pem');

// Base64エンコード
const keyBase64 = privateKey.toString('base64');

// 結果を表示
console.log(keyBase64);
