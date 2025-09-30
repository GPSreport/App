# 🔧 Cambios Necesarios en el Servidor EC2

## Para corregir el error "Error al obtener información del usuario":

### 1. Conectarse al servidor EC2:
```bash
ssh -i "C:\\Users\\USUARIO\\OneDrive\\Desktop\\Dis2025\\InstanciaAWS\\KeyREserver.pem" ubuntu@3.148.29.34
```

### 2. Editar el archivo main.py:
```bash
cd /opt/app
sudo nano main.py
```

### 3. Realizar estos cambios:

#### A) Agregar email al modelo LoginResponse (línea ~88):
```python
class LoginResponse(BaseModel):
    success: bool
    message: str
    usuario: Optional[str] = None
    numero_usuario: Optional[int] = None
    email: Optional[str] = None  # <-- AGREGAR ESTA LÍNEA
```

#### B) Modificar consulta SQL (línea ~514):
Cambiar:
```python
SELECT id, usuario, activo
```
Por:
```python
SELECT id, usuario, activo, correo
```

#### C) Modificar respuesta para cuenta no verificada (línea ~529):
Cambiar:
```python
raise HTTPException(
    status_code=401, 
    detail="Cuenta no verificada. Revisa tu correo electrónico para verificar tu cuenta."
)
```
Por:
```python
raise HTTPException(
    status_code=403,
    detail={
        "error": "Cuenta no verificada. Revisa tu correo electrónico para verificar tu cuenta.",
        "email": usuario_db['correo'],
        "usuario": usuario_db['usuario']
    }
)
```

#### D) Modificar respuesta exitosa (línea ~554):
Cambiar:
```python
return LoginResponse(
    success=True,
    message=f"Bienvenido {usuario_db['usuario']}",
    usuario=usuario_db['usuario'],
    numero_usuario=numero_usuario
)
```
Por:
```python
return LoginResponse(
    success=True,
    message=f"Bienvenido {usuario_db['usuario']}",
    usuario=usuario_db['usuario'],
    numero_usuario=numero_usuario,
    email=usuario_db['correo']  # <-- AGREGAR ESTA LÍNEA
)
```

### 4. Reiniciar el servidor:
```bash
sudo systemctl restart gps-app
sudo systemctl status gps-app
```

### 5. Verificar que funcione:
Probar la app Flutter nuevamente con un usuario no verificado.