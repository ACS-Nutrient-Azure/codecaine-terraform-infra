from flask import Flask, jsonify, request
import os

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'history'
    }), 200

@app.route('/history', methods=['GET'])
def get_history():
    return jsonify({
        'service': 'history',
        'message': 'History service is running',
        'data': [],
        'version': '1.0.0'
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
