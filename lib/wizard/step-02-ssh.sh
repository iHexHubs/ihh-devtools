#!/usr/bin/env bash
# Paso de wizard: gestión de llaves SSH.

# --- FIX: INTEGRACIÓN CON RUNTIME ---
# Importamos ssh-ident.sh para usar la misma lógica de agente que el resto del toolset
#
# FIX: Si este step se ejecuta aislado (sin setup-wizard.sh), LIB_BASE puede no existir.
: "${LIB_BASE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1090
source "${LIB_BASE}/ssh-ident.sh"

run_step_ssh() {
    ui_step_header "3. Configuración de Llaves de Seguridad"

    # Variable global que exportaremos para los siguientes pasos
    export SSH_KEY_FINAL=""
    
    # FIX: Usamos mapfile para manejar arrays de archivos correctamente
    local -a existing_keys_array
    mapfile -t existing_keys_array < <(find "$HOME/.ssh" -maxdepth 1 -name "id_*.pub" 2>/dev/null)
    
    local choice_gen="🔑 Generar NUEVA llave (Recomendado)"
    local choice_sel="📂 Seleccionar llave existente"
    local ssh_choice

    # 1. Decisión: Generar vs Seleccionar
    if [ ${#existing_keys_array[@]} -gt 0 ]; then
        ui_info "Selecciona cómo quieres firmar y autenticarte:"
        ssh_choice=$(gum choose "$choice_gen" "$choice_sel")
    else
        ssh_choice="$choice_gen"
    fi

    # 2. Ejecución de la decisión
    if [[ "$ssh_choice" == "$choice_gen" ]]; then
        generate_new_ssh_key
    else
        select_existing_ssh_key
    fi

    # 3. Carga en Agente SSH (Unificado)
    ui_spinner "Configurando Agente SSH..." sleep 1
    
    # --- FIX: AGENTE UNIFICADO ---
    # Usamos la función de ssh-ident.sh para garantizar que usamos el mismo agente
    # que usará git-acp en el futuro.
    load_or_start_agent
    
    # Agregar la llave privada
    if [ -f "$SSH_KEY_FINAL" ]; then
        chmod 600 "$SSH_KEY_FINAL"

        # Intentamos agregarla. Si falla, manejamos el error explícitamente.
        if ! ssh-add "$SSH_KEY_FINAL" 2>/dev/null; then
            ui_warn "⚠️ ssh-add falló al cargar la llave (posiblemente requiere passphrase)."
            ui_info "Intentando modo interactivo..."
            
            # Reintentar visiblemente para que pida pass
            ssh-add "$SSH_KEY_FINAL" || {
                ui_error "No se pudo cargar la llave en el agente."
                ui_info "Solución: Cárgala manualmente con 'ssh-add $SSH_KEY_FINAL' y reintenta."
            }
        else
            ui_success "Llave cargada en memoria (ssh-agent)."
        fi
    else
        ui_warn "No se encontró la llave privada local ($SSH_KEY_FINAL). El agente no la cargó."
    fi

    # 4. Subida a GitHub
    sync_ssh_key_to_github
}

generate_new_ssh_key() {
    local current_user_safe
    current_user_safe=$(gh api user -q ".login" || echo "user")
    
    local default_name="id_ed25519_${current_user_safe}"
    local key_name
    
    key_name=$(gum input --placeholder "Nombre del archivo" --value "$default_name" --header "Nombre para la llave (sin .pub)")
    SSH_KEY_FINAL="$HOME/.ssh/$key_name"
    
    # Validar si existe para no sobrescribir accidentalmente
    if [ -f "$SSH_KEY_FINAL" ]; then
        ui_warn "El archivo '$key_name' ya existe."
        if gum confirm "¿Quieres sobrescribirlo? (La anterior se perderá)"; then
            rm -f "$SSH_KEY_FINAL" "$SSH_KEY_FINAL.pub"
        else
            ui_error "Operación cancelada. Elige otro nombre."
            exit 1
        fi
    fi

    ui_spinner "Generando llave criptográfica..." \
        ssh-keygen -t ed25519 -C "devbox-${current_user_safe}" -f "$SSH_KEY_FINAL" -N "" -q
    
    ui_success "Llave creada en: $SSH_KEY_FINAL"
}

select_existing_ssh_key() {
    local -a keys
    mapfile -t keys < <(find "$HOME/.ssh" -maxdepth 1 -name "id_*.pub" 2>/dev/null)
    
    local selected_pub
    selected_pub=$(gum choose "${keys[@]}" --header "Selecciona la llave pública a usar:")
    SSH_KEY_FINAL="${selected_pub%.pub}"
    
    ui_success "Has seleccionado: $SSH_KEY_FINAL"
}

sync_ssh_key_to_github() {
    ui_step_header "4. Sincronizando Seguridad con GitHub"

    local key_title="Devbox-Key-$(date +%Y%m%d-%H%M)"
    local pub_key_content
    pub_key_content=$(cat "$SSH_KEY_FINAL.pub")
    local auth_uploaded=false
    local sign_uploaded=false

    ui_spinner "Intentando subir llaves automáticamente..." sleep 2

    # --------------------------------------------------------------------------
    # FASE 1: Llave de AUTENTICACIÓN (Crítica)
    # --------------------------------------------------------------------------
    if gh ssh-key add "$SSH_KEY_FINAL.pub" --title "$key_title (Auth)" --type authentication >/dev/null 2>&1; then
        auth_uploaded=true
        ui_success "✅ Llave de Autenticación subida (git push/pull habilitado)."
    else
        # Verificación: ¿Ya existía?
        local key_body
        key_body=$(echo "$pub_key_content" | cut -d' ' -f2)
        
        if gh ssh-key list | grep -q "$key_body"; then
            auth_uploaded=true
            ui_success "ℹ️ La llave ya estaba configurada para Autenticación."
        else
            ui_warn "⚠️ Falló la subida de la llave de Autenticación."
        fi
    fi

    # --------------------------------------------------------------------------
    # FASE 2: Llave de FIRMA (Opcional / Verified Commits)
    # --------------------------------------------------------------------------
    if gh ssh-key add "$SSH_KEY_FINAL.pub" --title "$key_title (Signing)" --type signing >/dev/null 2>&1; then
        sign_uploaded=true
        ui_success "✅ Llave de Firma subida (Verified Commits)."
    else
        local key_body
        key_body=$(echo "$pub_key_content" | cut -d' ' -f2)
        
        # Check suave para no romper en versiones viejas de gh o planes sin soporte
        if gh ssh-key list --type signing 2>/dev/null | grep -q "$key_body"; then
                ui_success "ℹ️ La llave ya estaba configurada para Firma."
                sign_uploaded=true
        else
                ui_warn "⚠️ No se pudo registrar como llave de Firma (Signing Key)."
                ui_info "Podrás hacer commits, pero no aparecerán como 'Verified'."
        fi
    fi

    # --------------------------------------------------------------------------
    # FASE 3: Fallback Manual (Solo si falló Auth)
    # --------------------------------------------------------------------------
    if [ "$auth_uploaded" = false ]; then
        ui_alert_box "⚠️ FALLÓ SUBIDA AUTOMÁTICA" \
            "Faltan permisos de escritura (write:public_key)." \
            "Vamos a hacerlo manualmente."

        echo ""
        ui_info "1. Copia tu llave pública:"
        echo "$pub_key_content" | ui_code_block
        
        if command -v xclip >/dev/null; then 
            echo "$pub_key_content" | xclip -sel clip
            ui_info "(Copiado al portapapeles automáticamente)"
        fi
        
        echo ""
        ui_info "2. Abre: https://github.com/settings/ssh/new"
        echo ""
        ui_info "3. Pega la llave, ponle título y guarda."
        
        if ! gum confirm "Presiona Enter cuando termines"; then
            ui_error "Cancelado."
            exit 1
        fi
    fi
}
