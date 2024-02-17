#!/bin/bash

# Función para imprimir mensajes con formato de título
print_title() {
    echo "== $1 =="
}

# Función para imprimir mensajes con formato de subsección
print_subtitle() {
    echo "-- $1 --"
}

# Función para instalar paquetes y manejar errores
install_package() {
    sudo apt-get -qq install "$1" || { echo "Error al instalar $1"; exit 1; }
}

# Actualización e instalación de paquetes básicos
print_title "INICIANDO"
sudo apt-get -qq update
sudo apt-get -qq upgrade
install_package "python3-dev"
install_package "python3-pip"
install_package "python3-venv"
install_package "sqlite3"
install_package "libsqlite3-dev"
install_package "nginx"
install_package "supervisor"
install_package "certbot"

# Instalación de la última versión de Python
print_title "INSTALANDO LA ÚLTIMA VERSIÓN DE PYTHON"
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get -qq update
install_package "python3.10"

# Configuración de Firewall
print_title "CONFIGURANDO FIREWALL (ufw)"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Configuración de SELinux (si está instalado)
if command -v getenforce &>/dev/null; then
    print_subtitle "CONFIGURANDO SELINUX"
    sudo setsebool -P httpd_can_network_connect 1
fi

# Función para obtener la opción del usuario (actualizar o crear)
get_user_option() {
    read -p "Seleccione una opción: 
    1. Actualizar un certificado existente para un proyecto.
    2. Crear un nuevo proyecto y configurar SSL.
    3. Salir.
    Su elección (1/2/3): " user_choice

    case $user_choice in
        1 ) update_existing_project;;
        2 ) create_new_project;;
        3 ) exit;;
        * ) echo "Opción no válida. Por favor, seleccione una opción válida (1/2/3).";;
    esac
}

# Función para actualizar un proyecto existente
update_existing_project() {
    print_subtitle "PROYECTOS EXISTENTES:"
    # Listar todos los proyectos en el directorio /home/django
    projects=(/home/django/*)
    for ((i=0; i<${#projects[@]}; i++)); do
        echo "$(($i+1)). ${projects[$i]##*/}"
    done
    
    # Solicitar al usuario que seleccione un número de proyecto
    read -p "Seleccione el número del proyecto que desea actualizar: " project_number
    if [[ $project_number =~ ^[0-9]+$ ]]; then
        if (( $project_number >= 1 && $project_number <= ${#projects[@]} )); then
            existing_project="${projects[$(($project_number-1))]}"
            sudo certbot certonly --nginx -d "${existing_project##*/}"
        else
            echo "Número de proyecto no válido."
        fi
    else
        echo "Por favor, ingrese un número válido."
    fi
}

# Función para crear un nuevo proyecto y configurar SSL
create_new_project() {
    read -p "Indique el nombre del nuevo proyecto: " new_project
    read -p "Indique el nombre de dominio asociado al proyecto: " domain_name
    sudo certbot certonly --nginx -d $domain_name
}

# Obtener la opción del usuario
get_user_option

# Fin del script
echo "=== FINALIZADO ==="
echo "Por favor, asegúrese de migrar la base de datos y recopilar los archivos estáticos manualmente después de ejecutar este script."
