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

origins = [
    "https://floodredfl.onrender.com", 
    "http://localhost:3000",           
    "http://127.0.0.1:3000",
    "http://localhost:5173",           # Added for Vite Frontend
    "http://127.0.0.1:5173",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ Global Exception Handler (Clears the JSONResponse warning)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"CRITICAL ERROR: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"message": "Internal Server Error", "detail": str(exc)}
    )

# ============= 3. MACHINE LEARNING CORE =============
class KolhapurFloodPredictor:
    """ML model trained on historical & synthetic flood data"""
    
    def __init__(self):
        self.model = RandomForestClassifier(
            n_estimators=150,
            max_depth=12,
            min_samples_split=5,
            min_samples_leaf=2,
            random_state=42,
            class_weight='balanced'
        )
        self.scaler = StandardScaler()
        self.feature_importance = {}
        self.is_trained = False
        
        self.load_pretrained_model()
    
    def load_pretrained_model(self):
        """Load pre-trained model if available, else train a new one"""
        if os.path.exists('flood_model.pkl') and os.path.exists('flood_scaler.pkl'):
            try:
                self.model = joblib.load('flood_model.pkl')
                self.scaler = joblib.load('flood_scaler.pkl')
                self.feature_importance = joblib.load('flood_features.pkl')
                self.is_trained = True
                print("✅ ML Model loaded successfully from disk!")
            except Exception as e:
                print(f"⚠️ Error loading model: {e}. Retraining...")
                self.train_with_real_data()
        else:
            print("⚠️ No pre-trained model found. Initializing training sequence...")
            self.train_with_real_data()
    
    def get_training_data(self):
        """Generates a robust 3-Class dataset: 0 (LOW), 1 (MODERATE), 2 (SEVERE)"""
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
                peak = np.random.uniform(12.2, 14.5)
                rain_7d = np.random.uniform(450, 700)
                dur = np.random.uniform(3, 7)
                label = 2
            elif rand > 0.33: 
                peak = np.random.uniform(10.5, 12.1)
                rain_7d = np.random.uniform(250, 449)
                dur = np.random.uniform(2, 4)
                label = 1
            else: 
                peak = np.random.uniform(5.0, 10.4)
                rain_7d = np.random.uniform(50, 249)
                dur = np.random.uniform(0, 2)
                label = 0
            
            rain_dist = np.random.dirichlet(np.ones(7), size=1)[0] * rain_7d
            
            event = [
                peak, dur, np.random.uniform(1, 3), np.random.uniform(1, 4),
                rain_dist[0], rain_dist[1], rain_dist[2], rain_dist[3], 
                rain_dist[4], rain_dist[5], rain_dist[6], label
            ]
            synthetic_data.append(event)
        
        all_data = real_events + synthetic_data
        X = np.array([event[:-1] for event in all_data])
        y = np.array([event[-1] for event in all_data])
        return X, y
    
    def train_with_real_data(self):
        """Train Random Forest with scaled features"""
        print("🔄 Training Multi-Class Flood Matrix...")
        X, y = self.get_training_data()
        
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
        
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        self.model.fit(X_train_scaled, y_train)
        
        accuracy = accuracy_score(y_test, self.model.predict(X_test_scaled))
        print(f"📈 Model Accuracy: {accuracy * 100:.1f}%")
        
        features = ['Peak_Level', 'Duration', 'Time_to_Peak', 'Recession', 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
        self.feature_importance = dict(zip(features, self.model.feature_importances_))
        
        self.is_trained = True
        joblib.dump(self.model, 'flood_model.pkl')
        joblib.dump(self.scaler, 'flood_scaler.pkl')
        joblib.dump(self.feature_importance, 'flood_features.pkl')
        print("✅ ML Matrix Trained & Saved to disk!")
    
    def predict_flood(self, input_data: FloodPredictionInput) -> Dict[str, Any]:
        """Core prediction logic bridging FastAPI to Sklearn"""
        try:
            features = np.array([[
                input_data.Peak_Flood_Level_m, input_data.Event_Duration_days,
                input_data.Time_to_Peak_days, input_data.Recession_Time_day,
                input_data.T1d, input_data.T2d, input_data.T3d,
                input_data.T4d, input_data.T5d, input_data.T6d, input_data.T7d
            ]])
            
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
                "model_trained": True,
                "danger_level": 12.0,
                "risk_score": round(confidence)
            }
            
        except Exception as e:
            print(f"❌ Prediction error: {e}. Executing Fallback.")
            return self.fallback_prediction(input_data)
    
    def fallback_prediction(self, input_data: FloodPredictionInput) -> Dict[str, Any]:
        """Hardcoded logic in case ML inference fails"""
        peak = input_data.Peak_Flood_Level_m
        rain = input_data.T7d
        
        if peak > 12.5 or rain > 450:
            sev, conf = "SEVERE", 92.5
        elif peak > 11.5 or rain > 300:
            sev, conf = "MODERATE", 78.3
        else:
            sev, conf = "LOW", 85.0
            
        return {
            "severity": sev,
            "confidence_percent": conf,
            "probabilities": {"SEVERE": conf if sev=="SEVERE" else 5, "MODERATE": conf if sev=="MODERATE" else 15, "LOW": conf if sev=="LOW" else 5},
            "alert": "🚨" if sev == "SEVERE" else "⚠️" if sev == "MODERATE" else "🟢",
            "algorithm": "Python Heuristic Fallback",
            "model_trained": False,
            "danger_level": 12.0,
            "risk_score": int(conf)
        }

predictor = KolhapurFloodPredictor()

# ============= 4. API ENDPOINTS =============
@app.get("/")
async def root():
    return {
        "service": "INDOFLOODS ML Server",
        "status": "Online",
        "model_ready": predictor.is_trained
    }

@app.post("/train")
async def force_retrain():
    """Endpoint to manually force the model to retrain"""
    predictor.train_with_real_data()
    return {"message": "Model retrained and saved successfully!"}

@app.post("/predict")
async def predict_flood(input_data: FloodPredictionInput):
    """Endpoint consumed by the frontend"""
    try:
        result = predictor.predict_flood(input_data)
        
        if result["severity"] == "SEVERE":
            result["monitoring"] = {
                "level": "CRITICAL EMERGENCY",
                "action": "Evacuate vulnerable river basins immediately.",
                "priority_zones": ["Primary Catchment", "Downstream Villages", "Low-lying urban zones"]
            }
        elif result["severity"] == "MODERATE":
            result["monitoring"] = {
                "level": "ELEVATED ALERT",
                "action": "Deploy monitoring teams & prep pumps.",
                "priority_zones": ["Drainage bottlenecks", "Main river gauge"]
            }
        else:
            result["monitoring"] = {
                "level": "STANDARD PROTOCOL",
                "action": "Maintain normal surveillance.",
                "priority_zones": ["None"]
            }
            
        print(f"✅ Served Prediction: {result['severity']} ({result['confidence_percent']}%)")
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ✅ Catch-All Route (Must be the very last route before __main__)
@app.api_route("/{path_name:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def catch_all(path_name: str):
    return JSONResponse(
        status_code=404, 
        content={"error": f"The path '{path_name}' was not found."}
    )

if __name__ == "__main__":
    print("🚀 Starting INDOFLOODS ML Backend...")
    # ✅ Fixed Port Binding for Render Compatibility
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)