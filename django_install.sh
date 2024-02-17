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

# Función para levantar el servidor
start_server() {
    sudo systemctl restart nginx
    sudo supervisorctl restart all
}

# Función para obtener la opción del usuario (actualizar o crear)
get_user_option() {
    read -p "Seleccione una opción: 
    1. Actualizar un certificado existente para un proyecto.
    2. Clonar y configurar un nuevo proyecto.
    3. Salir.
    Su elección (1/2/3): " user_choice

    case $user_choice in
        1 ) update_existing_project;;
        2 ) clone_and_configure_project;;
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

            # Levantar el servidor
            start_server
        else
            echo "Número de proyecto no válido."
        fi
    else
        echo "Por favor, ingrese un número válido."
    fi
}

# Función para clonar un nuevo proyecto y configurar SSL
clone_and_configure_project() {
    read -p "Indique la dirección del repositorio a clonar: " git_repo
    read -p "Indique el nombre de la carpeta del proyecto: " project_name
    read -p "Indique el nombre de la app principal de Django: " dj_app

    # Verificar si el directorio /home/django existe, si no, crearlo
    if [ ! -d "/home/django" ]; then
        sudo mkdir /home/django || { echo "Error: No se pudo crear el directorio /home/django"; exit 1; }
    fi

    # Cambiar al directorio /home/django
    cd /home/django || { echo "Error: No se pudo cambiar al directorio /home/django"; exit 1; }

    # Clonar el repositorio
    git clone "$git_repo" "$project_name" || { echo "Error al clonar el repositorio"; exit 1; }

    # Instalar dependencias
    pip install -q -r "/home/django/$project_name/requirements.txt" || { echo "Error al instalar las dependencias"; exit 1; }

    # Configurar certificado SSL
    read -p "Indique el nombre de dominio asociado al proyecto: " domain_name
    sudo certbot certonly --nginx -d "$domain_name" || { echo "Error al configurar el certificado SSL"; exit 1; }

    # Configurar Nginx
    sudo touch "/etc/nginx/sites-available/$project_name"
    sudo ln -s "/etc/nginx/sites-available/$project_name" "/etc/nginx/sites-enabled/$project_name"
    sudo rm /etc/nginx/sites-enabled/default

    # Configurar supervisor
    sudo touch "/etc/supervisor/conf.d/$project_name.conf"
    echo "[program:$project_name]" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "command=/home/django/.venv/bin/gunicorn_start" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "user=django" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "autostart=true" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "autorestart=true" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "redirect_stderr=true" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"
    echo "stdout_logfile=/home/django/logs/$project_name-error.log" | sudo tee -a "/etc/supervisor/conf.d/$project_name.conf"

    # Levantar el servidor
    start_server
}

# Función para crear el entorno virtual
create_virtual_environment() {
    sudo apt-get -qq install python3-venv || { echo "Error al instalar python3-venv"; exit 1; }
    python3 -m venv /home/django/.venv || { echo "Error al crear el entorno virtual"; exit 1; }
}

# Función para instalar paquetes básicos
install_basic_packages() {
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
    install_package "python3-certbot-nginx"
    install_package "git"
}

# Función principal
main() {
    print_title "INICIANDO SCRIPT"

    # Instalación de paquetes básicos
    print_title "INSTALANDO PAQUETES BÁSICOS"
    install_basic_packages

    # Crear el entorno virtual
    print_title "CREANDO ENTORNO VIRTUAL"
    create_virtual_environment

    # Obtener la opción del usuario
    get_user_option

    # Fin del script
    echo "=== FINALIZADO ==="
    echo "Por favor, asegúrese de migrar la base de datos y recopilar los archivos estáticos manualmente después de ejecutar este script."
}

# Llamar a la función principal
main
