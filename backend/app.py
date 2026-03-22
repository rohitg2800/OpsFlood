from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse             
from pydantic import BaseModel
import numpy as np
import joblib
from typing import Dict, Any
import uvicorn
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import warnings
import os

# --- NEW IMPORTS FOR SCRAPING ---
import requests
from bs4 import BeautifulSoup
import datetime

warnings.filterwarnings('ignore')

# ============= 1. PYDANTIC SCHEMA =============
class FloodPredictionInput(BaseModel):
    Peak_Flood_Level_m: float = 12.74
    Event_Duration_days: float = 3
    Time_to_Peak_days: float = 2
    Recession_Time_day: float = 2
    T1d: float = 156.4
    T2d: float = 299.2
    T3d: float = 384.4
    T4d: float = 384.4
    T5d: float = 384.4
    T6d: float = 384.4
    T7d: float = 455.6

# ============= 2. FASTAPI SETUP =============
app = FastAPI(title="🌧️ INDOFLOODS ML API", version="8.5")

# 🛡️ SECURE PRODUCTION CORS
origins = [
    "https://floodredfl.onrender.com",       
    "https://kolhapurfloodred.onrender.com", 
    "http://localhost:5173",                 
    "http://127.0.0.1:5173",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,    
    allow_credentials=False,   
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"CRITICAL ERROR: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"message": "Internal Server Error", "detail": str(exc)}
    )

# ============= 3. DATA ACQUISITION (CWC SCRAPER) =============
class CWCRiverScraper:
    def __init__(self):
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://ffs.india-water.gov.in/"
        }
        self.cwc_api_base = "https://ffs.india-water.gov.in/iam/api"

    def get_live_river_level(self, station_name="Kolhapur"):
        print(f"📡 Initiating secure connection to CWC Servers for {station_name}...")
        try:
            response = requests.get(f"{self.cwc_api_base}/new-warning-station", headers=self.headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                for station in data:
                    if station_name.lower() in station.get('stationName', '').lower():
                        level = station.get('waterLevel')
                        print(f"✅ SUCCESS: Live data fetched for {station['stationName']} ({level}m)")
                        return {
                            "status": "success",
                            "current_level_m": level,
                            "source": "CWC API"
                        }
            print("⚠️ API returned empty. Executing BeautifulSoup Fallback...")
            return self._beautifulsoup_fallback(station_name)
        except Exception as e:
            print(f"❌ CWC Scraper Error: {e}")
            return {"status": "error"}

    def _beautifulsoup_fallback(self, station_name):
        try:
            fallback_url = "https://ffs.india-water.gov.in/iam/api/report/state/Maharashtra"
            res = requests.get(fallback_url, headers=self.headers, verify=False, timeout=5)
            soup = BeautifulSoup(res.text, 'html.parser')
            rows = soup.find_all('tr')
            for row in rows:
                if station_name.lower() in row.text.lower():
                    columns = row.find_all('td')
                    if len(columns) > 3:
                        return {
                            "status": "success_fallback",
                            "current_level_m": float(columns[3].text.strip()),
                            "source": "HTML Scrape"
                        }
            return {"status": "error"}
        except Exception:
            return {"status": "error"}

# Initialize the scraper
cwc_scraper = CWCRiverScraper()

# ============= 4. MACHINE LEARNING CORE =============
class KolhapurFloodPredictor:
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=150, max_depth=12, min_samples_split=5, min_samples_leaf=2, random_state=42, class_weight='balanced')
        self.scaler = StandardScaler()
        self.feature_importance = {}
        self.is_trained = False
        self.load_pretrained_model()
    
    def load_pretrained_model(self):
        if os.path.exists('flood_model.pkl') and os.path.exists('flood_scaler.pkl'):
            try:
                self.model = joblib.load('flood_model.pkl')
                self.scaler = joblib.load('flood_scaler.pkl')
                self.is_trained = True
                print("✅ ML Model loaded successfully from disk!")
            except Exception:
                self.train_with_real_data()
        else:
            self.train_with_real_data()
    
    def get_training_data(self):
        real_events = [
            [13.5, 5, 2, 4, 180, 320, 420, 450, 480, 490, 550, 2],
            [12.8, 4, 2, 3, 160, 280, 380, 420, 450, 460, 480, 2],
            [11.8, 3, 2, 2, 120, 200, 280, 320, 350, 380, 400, 1],
            [11.2, 2, 1, 2, 100, 180, 250, 290, 320, 350, 370, 1],
            [9.5,  1, 1, 1,  50,  80, 100, 120, 150, 160, 180, 0],
            [8.0,  0, 0, 1,  10,  20,  30,  40,  50,  60,  80, 0],
        ]
        synthetic_data = []
        for _ in range(1000): 
            rand = np.random.random()
            if rand > 0.66: 
                peak, rain_7d, dur, label = np.random.uniform(12.2, 14.5), np.random.uniform(450, 700), np.random.uniform(3, 7), 2
            elif rand > 0.33: 
                peak, rain_7d, dur, label = np.random.uniform(10.5, 12.1), np.random.uniform(250, 449), np.random.uniform(2, 4), 1
            else: 
                peak, rain_7d, dur, label = np.random.uniform(5.0, 10.4), np.random.uniform(50, 249), np.random.uniform(0, 2), 0
            
            rain_dist = np.random.dirichlet(np.ones(7), size=1)[0] * rain_7d
            synthetic_data.append([peak, dur, np.random.uniform(1, 3), np.random.uniform(1, 4), rain_dist[0], rain_dist[1], rain_dist[2], rain_dist[3], rain_dist[4], rain_dist[5], rain_dist[6], label])
        
        all_data = real_events + synthetic_data
        return np.array([event[:-1] for event in all_data]), np.array([event[-1] for event in all_data])
    
    def train_with_real_data(self):
        print("🔄 Training Multi-Class Flood Matrix...")
        X, y = self.get_training_data()
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
        
        X_train_scaled = self.scaler.fit_transform(X_train)
        self.model.fit(X_train_scaled, y_train)
        
        self.is_trained = True
        joblib.dump(self.model, 'flood_model.pkl')
        joblib.dump(self.scaler, 'flood_scaler.pkl')
        print("✅ ML Matrix Trained & Saved!")
    
    def predict_flood(self, input_data: FloodPredictionInput, source: str = "Manual Input") -> Dict[str, Any]:
        try:
            features = np.array([[input_data.Peak_Flood_Level_m, input_data.Event_Duration_days, input_data.Time_to_Peak_days, input_data.Recession_Time_day, input_data.T1d, input_data.T2d, input_data.T3d, input_data.T4d, input_data.T5d, input_data.T6d, input_data.T7d]])
            features_scaled = self.scaler.transform(features)
            
            pred_class = self.model.predict(features_scaled)[0]
            probs = self.model.predict_proba(features_scaled)[0]
            classes = self.model.classes_.tolist()
            
            prob_dict = {"LOW": 0.0, "MODERATE": 0.0, "SEVERE": 0.0}
            for cls, prob in zip(classes, probs):
                if cls == 0: prob_dict["LOW"] = round(prob * 100, 1)
                elif cls == 1: prob_dict["MODERATE"] = round(prob * 100, 1)
                elif cls == 2: prob_dict["SEVERE"] = round(prob * 100, 1)
            
            severity_map = {0: "LOW", 1: "MODERATE", 2: "SEVERE"}
            severity = severity_map.get(pred_class, "LOW")
            confidence = max(probs) * 100
            
            return {
                "severity": severity,
                "confidence_percent": round(confidence, 1),
                "probabilities": prob_dict,
                "alert": "🚨" if severity == "SEVERE" else "⚠️" if severity == "MODERATE" else "🟢",
                "algorithm": "RandomForest Classifier (Live Inference)",
                "data_source": source, # Let the frontend know where the data came from!
                "model_trained": True,
                "danger_level": 12.0,
                "risk_score": round(confidence)
            }
        except Exception as e:
            return self.fallback_prediction(input_data)
    
    def fallback_prediction(self, input_data: FloodPredictionInput) -> Dict[str, Any]:
        peak, rain = input_data.Peak_Flood_Level_m, input_data.T7d
        if peak > 12.5 or rain > 450: sev, conf = "SEVERE", 92.5
        elif peak > 11.5 or rain > 300: sev, conf = "MODERATE", 78.3
        else: sev, conf = "LOW", 85.0
            
        return {
            "severity": sev,
            "confidence_percent": conf,
            "probabilities": {"SEVERE": conf if sev=="SEVERE" else 5, "MODERATE": conf if sev=="MODERATE" else 15, "LOW": conf if sev=="LOW" else 5},
            "alert": "🚨" if sev == "SEVERE" else "⚠️" if sev == "MODERATE" else "🟢",
            "algorithm": "Python Heuristic Fallback",
            "data_source": "Manual Input",
            "model_trained": False,
            "danger_level": 12.0,
            "risk_score": int(conf)
        }

predictor = KolhapurFloodPredictor()

# ============= 5. API ENDPOINTS =============
@app.get("/")
async def root():
    return {"service": "INDOFLOODS ML Server", "status": "Online", "model_ready": predictor.is_trained}

@app.post("/predict")
# NOTE: Changed to 'def' instead of 'async def' because the requests library is synchronous (blocking)
def predict_flood(input_data: FloodPredictionInput):
    """Endpoint consumed by the frontend"""
    try:
        data_source = "Frontend Manual Input"
        
        # 🌊 OVERRIDE WITH LIVE CWC DATA
        print("🔄 Fetching live data from Central Water Commission...")
        live_data = cwc_scraper.get_live_river_level("Kolhapur")
        
        if live_data.get("status") in ["success", "success_fallback"]:
            live_level = live_data.get("current_level_m")
            if live_level is not None:
                input_data.Peak_Flood_Level_m = float(live_level)
                data_source = f"Live CWC Sensor ({live_data['source']})"
                print(f"🌊 OVERRIDE: Using Authentic Live CWC Level: {input_data.Peak_Flood_Level_m}m")
        else:
            print("⚠️ CWC Servers unavailable. Proceeding with user's manual input.")

        # Get ML Response
        result = predictor.predict_flood(input_data, source=data_source)
        
        # Attach Monitoring Protocols
        if result["severity"] == "SEVERE":
            result["monitoring"] = {"level": "CRITICAL EMERGENCY", "action": "Evacuate vulnerable river basins immediately.", "priority_zones": ["Primary Catchment", "Downstream Villages", "Low-lying urban zones"]}
        elif result["severity"] == "MODERATE":
            result["monitoring"] = {"level": "ELEVATED ALERT", "action": "Deploy monitoring teams & prep pumps.", "priority_zones": ["Drainage bottlenecks", "Main river gauge"]}
        else:
            result["monitoring"] = {"level": "STANDARD PROTOCOL", "action": "Maintain normal surveillance.", "priority_zones": ["None"]}
            
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.api_route("/{path_name:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def catch_all(path_name: str):
    return JSONResponse(status_code=404, content={"error": f"The path '{path_name}' was not found."})

if __name__ == "__main__":
    print("🚀 Starting INDOFLOODS ML Backend...")
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)