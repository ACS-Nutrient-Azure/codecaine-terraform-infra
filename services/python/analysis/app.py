from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'analysis'
    }), 200

@app.route('/api/analyze', methods=['POST'])
def analyze():
    return jsonify({
        'service': 'analysis',
        'message': 'Analysis service is running',
        'version': '1.0.0'
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
