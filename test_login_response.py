#!/usr/bin/env python3
"""
Script de prueba para verificar la respuesta del endpoint de login
"""

import requests
import json

# Configuración
BASE_URL = "http://3.148.29.34"
TEST_USER = "testverify"  # Usuario no verificado
TEST_PASSWORD = "123456"

def test_login_response():
    """Probar login para ver la estructura exacta de la respuesta"""
    print("🔸 Probando login con usuario no verificado...")
    
    url = f"{BASE_URL}/login"
    data = {
        "usuario": TEST_USER,
        "clave": TEST_PASSWORD
    }
    
    try:
        response = requests.post(url, json=data, timeout=10)
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        
        try:
            response_json = response.json()
            print(f"Response JSON: {json.dumps(response_json, indent=2)}")
            
            # Analizar la estructura
            if response.status_code == 403:
                print("\n🔍 Analizando estructura del error 403:")
                detail = response_json.get('detail')
                if isinstance(detail, dict):
                    print(f"   detail es un dict: {detail}")
                    print(f"   email en detail: {detail.get('email')}")
                else:
                    print(f"   detail es string: {detail}")
                    
        except json.JSONDecodeError:
            print(f"Response Text: {response.text}")
            
    except Exception as e:
        print(f"❌ Error en la petición: {e}")

if __name__ == "__main__":
    test_login_response()