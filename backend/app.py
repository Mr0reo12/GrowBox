from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
import logging
from datetime import datetime
import time
from functools import wraps

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///growbox.db?check_same_thread=False'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {'connect_args': {'timeout': 30}}
db = SQLAlchemy(app)

# Configuración de logging
logging.basicConfig(level=logging.DEBUG)

class SensorData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    temperature = db.Column(db.Float, nullable=False)
    humidity = db.Column(db.Float, nullable=False)
    timestamp = db.Column(db.DateTime, default=db.func.current_timestamp(), nullable=False)

class Control(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    state = db.Column(db.String(50), nullable=False)
    mode = db.Column(db.String(50), nullable=False)  # "manual" or "automatic"
    start_time = db.Column(db.Time, nullable=True)  # Time to turn on
    end_time = db.Column(db.Time, nullable=True)  # Time to turn off

# Crear las tablas de la base de datos dentro del contexto de la aplicación
with app.app_context():
    db.create_all()

def retry_on_lock(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        retries = 5
        for i in range(retries):
            try:
                return f(*args, **kwargs)
            except Exception as e:
                if "database is locked" in str(e):
                    time.sleep(1)  # Esperar 1 segundo antes de reintentar
                    continue
                else:
                    raise
        return jsonify({'status': 'error', 'message': 'Database is locked after multiple retries'}), 500
    return wrapper

@app.route('/api/sensor-data', methods=['POST'])
@retry_on_lock
def receive_data():
    data = request.json
    logging.debug(f"Received sensor data: {data}")
    new_data = SensorData(temperature=data['temperature'], humidity=data['humidity'])
    db.session.add(new_data)
    db.session.commit()
    db.session.close()
    return jsonify({'status': 'success'}), 200

@app.route('/api/sensor-data', methods=['GET'])
def get_data():
    try:
        latest_data = SensorData.query.order_by(SensorData.timestamp.desc()).first()
        db.session.close()
        return jsonify({
            'temperature': latest_data.temperature,
            'humidity': latest_data.humidity,
            'timestamp': latest_data.timestamp
        }), 200
    except Exception as e:
        logging.error(f"Error getting sensor data: {e}")
        db.session.close()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/control', methods=['POST'])
@retry_on_lock
def set_control():
    try:
        data = request.json
        logging.debug(f"Received control data: {data}")
        control = Control.query.first()

        # Convertir start_time y end_time a objetos time
        start_time = datetime.strptime(data['start_time'], '%H:%M:%S').time() if data.get('start_time') else None
        end_time = datetime.strptime(data['end_time'], '%H:%M:%S').time() if data.get('end_time') else None

        if not control:
            control = Control(state=data['state'], mode=data['mode'], start_time=start_time, end_time=end_time)
        else:
            control.state = data['state']
            control.mode = data['mode']
            control.start_time = start_time
            control.end_time = end_time
        db.session.add(control)
        db.session.commit()
        db.session.close()
        return jsonify({'status': 'success'}), 200
    except Exception as e:
        logging.error(f"Error setting control: {e}")
        db.session.rollback()
        db.session.close()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/control', methods=['GET'])
def get_control():
    try:
        control = Control.query.first()
        if control is None:
            with app.app_context():
                control = Control(state='OFF', mode='manual')
                db.session.add(control)
                db.session.commit()
        db.session.close()
        return jsonify({
            'state': control.state,
            'mode': control.mode,
            'start_time': control.start_time.strftime('%H:%M:%S') if control.start_time else None,
            'end_time': control.end_time.strftime('%H:%M:%S') if control.end_time else None
        }), 200
    except Exception as e:
        logging.error(f"Error getting control: {e}")
        db.session.close()
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
