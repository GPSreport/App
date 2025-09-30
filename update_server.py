#!/usr/bin/env python3
"""
Script para actualizar el archivo main.py en el servidor EC2
"""

# Copiamos el contenido actualizado que debe ir al servidor
updated_main_py = '''
# Los cambios principales son:

1. En LoginResponse (línea ~83):
class LoginResponse(BaseModel):
    success: bool
    message: str
    usuario: Optional[str] = None
    numero_usuario: Optional[int] = None
    email: Optional[str] = None  # <- NUEVO CAMPO

2. En la consulta SQL del login (línea ~509):
        cursor.execute('''
        SELECT id, usuario, activo, correo  # <- AGREGADO correo
        FROM usuarios
        WHERE usuario = %s AND clave_hash = %s
        ''', (request.usuario.strip(), clave_hash))

3. En la verificación de cuenta no verificada (línea ~524):
            if usuario_db['activo'] == 1:
                cursor.close()
                conn.close()
                # Para cuentas no verificadas, devolver información especial
                raise HTTPException(
                    status_code=403,  # Cambiado de 401 a 403
                    detail={
                        "error": "Cuenta no verificada. Revisa tu correo electrónico para verificar tu cuenta.",
                        "email": usuario_db['correo'],  # <- INCLUIR EMAIL
                        "usuario": usuario_db['usuario']
                    }
                )

4. En la respuesta exitosa del login (línea ~549):
            return LoginResponse(
                success=True,
                message=f"Bienvenido {usuario_db['usuario']}",
                usuario=usuario_db['usuario'],
                numero_usuario=numero_usuario,
                email=usuario_db['correo']  # <- INCLUIR EMAIL
            )
'''

print("📝 Cambios necesarios en main.py del servidor EC2:")
print(updated_main_py)
print("\n🔧 Para aplicar los cambios:")
print("1. Conectarse al servidor EC2")
print("2. Editar /opt/app/main.py")
print("3. Aplicar los cambios mostrados arriba")
print("4. Reiniciar el servidor con: sudo systemctl restart gps-app")