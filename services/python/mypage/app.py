from flask import Flask, jsonify, request
import os

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'mypage'
    }), 200

@app.route('/mypage', methods=['GET'])
def mypage_root():
    return jsonify({
        'service': 'mypage',
        'message': 'MyPage service is running',
        'version': '1.0.0'
    }), 200

@app.route('/mypage/profile', methods=['GET'])
def get_profile():
    return jsonify({
        'service': 'mypage',
        'message': 'MyPage profile endpoint',
        'profile': {
            'user': 'sample_user',
            'email': 'user@example.com'
        },
        'version': '1.0.0'
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
