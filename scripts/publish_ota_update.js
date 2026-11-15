/**
 * Script de Despliegue Rápido OTA (Over-The-Air) para UMBRAL IMMUJER
 * Sube el APK a Supabase Storage (bucket 'app-updates'), publica version.json
 * y actualiza configuracion_general en caliente para la app móvil.
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://kkgacvhbcxgoxjpnkxmw.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_KEY) {
  console.error('Error: No se encontró SUPABASE_ANON_KEY ni SUPABASE_SERVICE_ROLE_KEY en .env');
  process.exit(1);
}

const adminEmail = process.env.SUPERADMIN_EMAIL || process.env.ADMIN_EMAIL;
const adminPassword = process.env.SUPERADMIN_PASSWORD || process.env.ADMIN_PASSWORD;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: false },
});

async function deployOTA() {
  console.log('--- Iniciando Despliegue OTA UMBRAL IMMUJER ---');

  if (adminEmail && adminPassword && !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.log(`Iniciando sesión como Super Admin (${adminEmail})...`);
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: adminEmail,
      password: adminPassword,
    });
    if (authError) {
      console.warn(`No se pudo autenticar como Super Admin: ${authError.message}`);
    } else {
      console.log('Autenticación Super Admin exitosa.');
    }
  }

  // 1. Extraer versión de pubspec.yaml si está disponible
  let version = '0.1.6';
  let buildNumber = 7;
  const pubspecPath = path.resolve(__dirname, '../pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
    const match = pubspecContent.match(/version:\s*([0-9.]+)\+([0-9]+)/);
    if (match) {
      version = match[1];
      buildNumber = parseInt(match[2], 10);
    }
  }

  console.log(`Versión objetivo: ${version}+${buildNumber}`);

  // 2. Comprobar si existe el binario APK compilado
  const apkPath = path.resolve(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');
  let apkPublicUrl = `https://github.com/VladimirArguelles/umbral_immujer/releases/download/latest/app-release.apk`;

  const bucketName = 'app-updates';

  if (fs.existsSync(apkPath)) {
    console.log(`Encontrado APK local: ${apkPath}`);
    const apkBuffer = fs.readFileSync(apkPath);
    console.log(`Subiendo APK a Supabase Storage [${bucketName}/app-release.apk] (${(apkBuffer.length / (1024 * 1024)).toFixed(2)} MB)...`);

    const { error: uploadError } = await supabase.storage
      .from(bucketName)
      .upload('app-release.apk', apkBuffer, {
        contentType: 'application/vnd.android.package-archive',
        upsert: true,
      });

    if (uploadError) {
      console.warn(`Advertencia al subir APK a Storage: ${uploadError.message}`);
    } else {
      const { data: publicUrlData } = supabase.storage
        .from(bucketName)
        .getPublicUrl('app-release.apk');
      if (publicUrlData && publicUrlData.publicUrl) {
        apkPublicUrl = publicUrlData.publicUrl;
        console.log(`APK disponible en: ${apkPublicUrl}`);
      }
    }
  } else {
    console.log(`No se encontró APK en ${apkPath}. Se mantendrá la URL de descarga canónica.`);
  }

  // 3. Crear y subir version.json a Supabase Storage
  const versionPayload = {
    version: version,
    build_number: buildNumber,
    mandatory: false,
    notes: 'Actualización en caliente con Deep Link y soporte OTA integrado.',
    apk_url: apkPublicUrl,
    updated_at: new Date().toISOString(),
  };

  console.log(`Subiendo version.json a bucket ${bucketName}...`);
  const { error: versionError } = await supabase.storage
    .from(bucketName)
    .upload('version.json', Buffer.from(JSON.stringify(versionPayload, null, 2)), {
      contentType: 'application/json',
      upsert: true,
    });

  if (versionError) {
    console.warn(`Aviso al subir version.json a Storage: ${versionError.message}`);
  } else {
    console.log('version.json subido exitosamente a Supabase Storage.');
  }

  // 4. Sincronizar configuracion_general en Supabase
  console.log('Actualizando configuracion_general en base de datos...');
  const updates = [
    { clave: 'app_version_latest', valor: JSON.stringify(version) },
    { clave: 'app_build_number', valor: JSON.stringify(buildNumber) },
    { clave: 'app_apk_url', valor: JSON.stringify(apkPublicUrl) },
    { clave: 'app_update_notes', valor: JSON.stringify(versionPayload.notes) },
  ];

  for (const item of updates) {
    const { error } = await supabase
      .from('configuracion_general')
      .update({ valor: item.valor, actualizado_en: new Date().toISOString() })
      .eq('clave', item.clave);

    if (error) {
      console.warn(`Error actualizando ${item.clave}: ${error.message}`);
    }
  }

  console.log('--- Despliegue OTA Finalizado Exitosamente ---');
  console.log(`Versión activa en servidor: ${version}+${buildNumber}`);
  console.log(`URL de descarga: ${apkPublicUrl}`);
}

deployOTA().catch(err => {
  console.error('Error fatal durante despliegue OTA:', err);
  process.exit(1);
});
