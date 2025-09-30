#!/usr/bin/env python3
"""
Script de prueba para verificar los endpoints de verificación por código
"""

import requests
import json

# Configuración
BASE_URL = "http://3.148.29.34"
TEST_EMAIL = "gpsreportbaq@gmail.com"
TEST_USER = "testverify"
TEST_PASSWORD = "123456"

def test_login():
    """Probar login para obtener email del usuario"""
    print("🔸 Probando login para obtener email...")
    
    url = f"{BASE_URL}/login"
    data = {
        "usuario": TEST_USER,
        "clave": TEST_PASSWORD
    }
    
    try:
        response = requests.post(url, json=data, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print(f"✅ Login exitoso - Email: {result.get('email', 'No disponible')}")
                return result.get('email')
            else:
                print(f"❌ Login falló: {result.get('message', 'Error desconocido')}")
        else:
            print(f"❌ Error en login: {response.status_code}")
        
        return None
            
    except Exception as e:
        print(f"❌ Error en la petición: {e}")
        return None

def test_enviar_codigo(email):
    """Probar endpoint de envío de código"""
    print(f"\n🔸 Probando envío de código a {email}...")
    
    url = f"{BASE_URL}/enviar-codigo"
    data = {"email": email}
    
    try:
        response = requests.post(url, json=data, timeout=15)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            print("✅ Código enviado correctamente")
            return True
        else:
            print(f"❌ Error enviando código")
            return False
            
    except Exception as e:
        print(f"❌ Error en la petición: {e}")
        return False

def test_estado_usuario(email):
    """Probar endpoint de estado del usuario"""
    print(f"\n🔸 Probando consulta de estado para {email}...")
    
    url = f"{BASE_URL}/usuario-estado/{email}"
    
    try:
        response = requests.get(url, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Usuario: {data['nombre']}")
            print(f"✅ Email: {data['email']}")
            print(f"✅ Verificado: {data['verificado']}")
            print(f"✅ Estado: {data['estado_texto']}")
            return True
        else:
            print(f"❌ Error consultando estado")
            return False
            
    except Exception as e:
        print(f"❌ Error en la petición: {e}")
        return False

def main():
    """Función principal de pruebas"""
    print("🧪 Iniciando pruebas de verificación por código de 6 dígitos")
    print(f"🌐 Servidor: {BASE_URL}")
    print(f"📧 Email de prueba: {TEST_EMAIL}")
    print("-" * 70)
    
    # Probar login para obtener email
    email = test_login()
    
    if email:
        # Probar estado del usuario
        test_estado_usuario(email)
        
        # Probar envío de código
        if test_enviar_codigo(email):
            print(f"\n📧 Revisa el email {email} para ver el código de 6 dígitos")
            print("⏳ El código expira en 15 minutos")
            
            # Permitir al usuario probar la verificación manualmente
            print("\n💡 Para probar la verificación completa:")
            print("   1. Abre la app Flutter")
            print("   2. Intenta hacer login con credenciales no verificadas")
            print("   3. Presiona 'Enviar código de verificación'")
            print("   4. Ve a 'Mi Perfil' y usa el código recibido")
    
    print("\n🏁 Pruebas completadas")

if __name__ == "__main__":
    main()