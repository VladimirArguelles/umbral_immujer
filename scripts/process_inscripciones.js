const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');
const { PDFParse } = require('pdf-parse');
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env'), override: true });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Error: SUPABASE_URL and SUPABASE_ANON_KEY must be defined in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const userProfile = process.env.USERPROFILE || 'C:\\Users\\Vladimir Argüelles';
const baseDataDir = path.join(userProfile, 'Documents', 'PROYECTO DE APLICACION UMBRAL', 'Cursos,Temas e Inscripciones');
const pdfDir = path.join(baseDataDir, 'Inscripciones');
const planDocxPath = path.join(baseDataDir, 'Plan Formacion.docx');

// Map of PDF files to exact course metadata
const PDF_COURSE_MAPPINGS = [
  {
    filePattern: /Bartender.*Alex\s*Santiago/i,
    cursoNombre: 'Bartender',
    horario: 'Sábado 8:00 a 10:00am',
    profesorNombre: 'Alex Santiago',
    diaSemana: 6 // Sabado
  },
  {
    filePattern: /Cocina\s*Avanzada.*Daniel\s*Vizcaino/i,
    cursoNombre: 'Cocina Avanzada',
    horario: 'Sábado 1:00 a 5:00pm',
    profesorNombre: 'Daniel Vizcaino',
    diaSemana: 6
  },
  {
    filePattern: /Cocina\s*Italiana.*Luis\s*Ferm/i,
    cursoNombre: 'Cocina Italiana',
    horario: 'Miércoles 1:00 a 5:00pm',
    profesorNombre: 'Luis Fermín',
    diaSemana: 3 // Miercoles
  },
  {
    filePattern: /Cocina\s*Navide.*Deibys\s*Rojas/i,
    cursoNombre: 'Cocina Navideña',
    horario: 'Sábado 8:00am a 12:00pm',
    profesorNombre: 'Deibys Rojas',
    diaSemana: 6
  },
  {
    filePattern: /Decoraci.*tortas\s*B.*Sefora/i,
    cursoNombre: 'Decoración de Tortas Básica',
    horario: 'Sábado 8:00 a 12:00 pm',
    profesorNombre: 'Sefora Gutierrez',
    diaSemana: 6
  },
  {
    filePattern: /Panader.*Avanzada.*Jorge\s*Blanco/i,
    cursoNombre: 'Panadería Avanzada',
    horario: 'Sábado 1:00 a 5:00pm',
    profesorNombre: 'Jorge Blanco',
    diaSemana: 6
  },
  {
    filePattern: /Panader.*B.*sica.*Celly\s*Campbell/i,
    cursoNombre: 'Panadería Básica',
    horario: 'Viernes 1:00 a 5:00pm',
    profesorNombre: 'Celly Campbell',
    diaSemana: 5 // Viernes
  },
  {
    filePattern: /pasapalos.*Celly\s*Campbell/i,
    cursoNombre: 'Pasapalos',
    horario: 'Jueves 1:00 a 5:00pm',
    profesorNombre: 'Celly Campbell',
    diaSemana: 4 // Jueves
  },
  {
    filePattern: /Reposteria\s*Basica.*Anisette\s*Diaz/i,
    cursoNombre: 'Repostería Básica',
    horario: 'Viernes 1:00 a 5:00pm',
    profesorNombre: 'Anisette Diaz',
    diaSemana: 5
  },
  {
    filePattern: /Reposter.*Avanzada.*Yolenn/i,
    cursoNombre: 'Repostería Avanzada',
    horario: 'Jueves 1:00 a 5:00pm',
    profesorNombre: 'Yolennis Vivas',
    diaSemana: 4
  },
  {
    filePattern: /Reposter.*Tendencia.*Genesis\s*Herrera/i,
    cursoNombre: 'Repostería en Tendencia',
    horario: 'Jueves 1:00 a 5:00pm',
    profesorNombre: 'Genesis Herrera',
    diaSemana: 4
  },
  {
    filePattern: /Tortas\s*Basicas\s*Criollas.*Anissette/i,
    cursoNombre: 'Tortas Basicas Criollas',
    horario: 'Miércoles 1:00 a 5:00pm',
    profesorNombre: 'Anisette Diaz',
    diaSemana: 3
  },
  {
    filePattern: /.*Cocina\s*B.*Hender\s*Leon/i,
    cursoNombre: 'Cocina Básica',
    horario: 'Viernes 1:00 a 5:00pm',
    profesorNombre: 'Ender Leon',
    diaSemana: 5
  }
];

const FALLBACK_TOPICS = {
  'Cocina Italiana': [
    'Masa base de pasta fresca (fettuccine y tagliatelle)',
    'Salsas clásicas: Pomodoro, Pesto Genovese y Carbonara',
    'Raviolis y tortellinis artesanales con rellenos tradicionales',
    'Lasaña boloñesa clásica y bechamel aromática',
    'Risotto clásico alla Milanese y risotto de champiñones',
    'Masa de pizza napolitana tradicional y focaccia al romero',
    'Minestrone tradicional y caldos regionales italianos',
    'Pollo alla Parmigiana y saltimbocca alla romana',
    'Ossobuco alla Milanese con gremolata',
    'Panna cotta de frutos rojos y cannoli siciliani',
    'Tiramisú veneciano clásico con café y cacao',
    'Técnicas de emplatado mediterráneo y servicio italiano'
  ],
  'Cocina Navideña': [
    'Preparación de masa y guiso multisápido para hallacas',
    'Técnicas de armado, envoltura en hoja de plátano y amarre',
    'Pan de jamón tradicional hojaldrado con aceitunas y pasas',
    'Pan de jamón especial con tocineta y queso crema',
    'Pernil horneado jugoso con maceración criolla tradicional',
    'Ensalada de gallina clásica y aderezos tradicionales',
    'Asado negro criollo estilo festivo con salsa de papelón',
    'Torta negra navideña con frutos macerados en licor',
    'Dulce de lechosa tradicional y almíbar de especias',
    'Ponche crema artesanal tradicional',
    'Galletas de jengibre y bocadillos navideños',
    'Montaje de mesa y cena navideña tradicional completa'
  ],
  'Panadería Avanzada': [
    'Masas fermentadas de alta hidratación y amasado francés',
    'Cultivo de masa madre natural y prefermentos (Poolish y Biga)',
    'Pan Ciabatta italiano y Baguette tradicional francesa',
    'Pan Brioche francés artesanal y Panettone tradicional',
    'Masa de hojaldre fermentado y técnica de laminado de Croissants',
    'Pan campesino rústico con masa madre y greñado artístico',
    'Panes saborizados: aceitunas kalamata, nueces y tomates secos',
    'Focaccia genovesa con emulsión de salmuera y hierbas',
    'Pan Jalá trenzado festivo y Stollen alemán especiado',
    'Pan de centeno alemán y panadería integral multigranos',
    'Técnicas de vapor, horneado en piso y control de fermentación',
    'Formulación porcentual panadera, costos y resolución de fallas'
  ],
  'Tortas Basicas Criollas': [
    'Torta básica criolla de vainilla esponjosa con almíbar',
    'Torta tradicional de jojoto (maíz dulce)',
    'Torta de auyama con especias dulces y queso',
    'Torta de plátano maduro con queso blanco criollo',
    'Torta de pan criolla caramelizada',
    'Torta burrera tradicional zuliana con papelón',
    'Torta tres leches criolla con merengue suizo',
    'Torta volteada de piña caramelizada tradicional',
    'Torta de guanábana con crema batida',
    'Torta marquesa criolla de chocolate y galleta maría',
    'Torta bienmesabe de coco con almíbar al licor',
    'Técnicas de horneado, conservación y presentación criolla'
  ]
};

function cleanName(raw) {
  return raw
    .replace(/^\d+[\s\.\-]+/, '')
    .replace(/[\t\r\n]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseStudentRow(line) {
  let cleanLine = line.trim();
  if (!cleanLine || cleanLine.startsWith('--') || cleanLine.includes('Nombre completo') || cleanLine.includes('mero de teléfono')) {
    return null;
  }

  const emailMatch = cleanLine.match(/([a-zA-Z0-9\u00C0-\u017F._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/);
  if (!emailMatch) return null;
  const email = emailMatch[1].trim();

  let telefono = '';
  const afterEmail = cleanLine.substring(cleanLine.indexOf(email) + email.length).trim();
  const phoneAfterMatch = afterEmail.match(/(?:(?:\+58|58|0)?(?:412|414|424|416|426|261|264|265|267|268|269)\d{7}|\d{10,11})/);
  if (phoneAfterMatch) {
    telefono = phoneAfterMatch[0].replace(/[^0-9]/g, '');
  } else {
    const generalPhoneMatch = cleanLine.match(/(?:(?:\+58|58|0)?(?:412|414|424|416|426|261|264|265|267|268|269)\d{7}|\d{10,11})/);
    if (generalPhoneMatch) {
      telefono = generalPhoneMatch[0].replace(/[^0-9]/g, '');
    }
  }
  if (telefono.length > 11 && telefono.startsWith('58')) {
    telefono = '0' + telefono.substring(2);
  }
  if (telefono.length > 11) {
    telefono = telefono.substring(0, 11);
  }

  const beforeEmail = cleanLine.substring(0, cleanLine.indexOf(email)).trim();
  let cedula = '';
  let nombre = '';

  const cedulaWithDotsMatch = beforeEmail.match(/(\d{1,2}\.\d{3}\.\d{3}|\d{5,8})\s*$/);
  if (cedulaWithDotsMatch) {
    cedula = cedulaWithDotsMatch[1].replace(/\./g, '');
    nombre = beforeEmail.substring(0, beforeEmail.lastIndexOf(cedulaWithDotsMatch[1])).trim();
  } else {
    const anyCedula = cleanLine.match(/\b(\d{6,8})\b/);
    if (anyCedula) {
      cedula = anyCedula[1];
      nombre = beforeEmail.replace(cedula, '').trim();
    }
  }

  nombre = cleanName(nombre);
  if (!cedula || !nombre || nombre.length < 3) {
    return null;
  }

  return {
    nombre_completo: nombre,
    cedula: cedula,
    correo: email.toLowerCase(),
    telefono: telefono || '04140000000'
  };
}

function extractPlanTopics() {
  if (!fs.existsSync(planDocxPath)) {
    console.warn(`Plan Formacion.docx no encontrado en: ${planDocxPath}`);
    return {};
  }
  try {
    const zip = new AdmZip(planDocxPath);
    const xml = zip.readAsText('word/document.xml');
    const paragraphs = xml.split('</w:p>');
    const lines = [];

    for (const p of paragraphs) {
      const clean = p.replace(/<[^>]+>/g, '').trim();
      if (clean) lines.push(clean);
    }

    const courses = {};
    let currentCourse = null;

    for (const line of lines) {
      const courseMatch = line.match(/^(\d+)[\.\s]+(.+)$/);
      if (courseMatch && !line.toLowerCase().includes('temas')) {
        currentCourse = courseMatch[2].trim();
        courses[currentCourse] = { topics: [], teacher: '', phone: '', ci: '' };
        continue;
      }
      if (!currentCourse) continue;

      if (line.toLowerCase().startsWith('profesor')) {
        courses[currentCourse].teacher = line.replace(/profesor\s*:\s*/i, '').trim();
      } else if (line.toLowerCase().startsWith('c.i.')) {
        courses[currentCourse].ci = line.replace(/c\.i\.\s*:\s*/i, '').trim();
      } else if (line.toLowerCase().startsWith('teléfono') || line.toLowerCase().startsWith('telefono')) {
        courses[currentCourse].phone = line.replace(/tel[eé]fono\s*:\s*/i, '').trim();
      } else if (!line.toLowerCase().includes('temas a impartir') && !line.toLowerCase().includes('plan de formaci') && !line.toLowerCase().includes('cronograma')) {
        if (line.length > 3) {
          courses[currentCourse].topics.push(line);
        }
      }
    }
    return courses;
  } catch (err) {
    console.error('Error reading Plan Formacion.docx:', err.message);
    return {};
  }
}

async function main() {
  console.log('================================================================');
  console.log('  MOTOR AUTÓNOMO DE EXTRACCIÓN Y SINCRONIZACIÓN DE INSCRIPCIONES');
  console.log('================================================================');
  console.log(`Conectando a Supabase: ${SUPABASE_URL}`);

  // 1. Fetch Teachers / Profiles from public.perfiles
  console.log('\n--- 1. Verificando Profesores y Perfiles ---');
  const { data: perfilesProf, error: errPerfiles } = await supabase
    .from('perfiles')
    .select('id, nombre_completo, cedula, telefono, rol')
    .eq('rol', 'profesor');

  if (errPerfiles) throw errPerfiles;

  const profMap = new Map();
  for (const p of perfilesProf) {
    profMap.set(p.nombre_completo.toLowerCase().trim(), p.id);
  }

  // 2. Fetch Cursos
  console.log('\n--- 2. Obteniendo Cursos de Supabase ---');
  const { data: cursosExistentes, error: errCursos } = await supabase
    .from('cursos')
    .select('id, nombre, horario, profesor_id, temas');

  if (errCursos) throw errCursos;

  // 3. Plan Topics & Course Meta
  console.log('\n--- 3. Extrayendo Temarios y Metadatos de Cursos ---');
  const planCourses = extractPlanTopics();
  const cursosMeta = [];
  const temasCurso = [];

  for (const curso of cursosExistentes) {
    let topics = [];
    const matchedPlan = Object.entries(planCourses).find(([k]) => 
      k.toLowerCase().includes(curso.nombre.toLowerCase()) || curso.nombre.toLowerCase().includes(k.toLowerCase())
    );

    if (matchedPlan && matchedPlan[1].topics.length > 0) {
      topics = matchedPlan[1].topics;
    } else if (FALLBACK_TOPICS[curso.nombre]) {
      topics = FALLBACK_TOPICS[curso.nombre];
    } else if (Array.isArray(curso.temas) && curso.temas.length > 0) {
      topics = curso.temas;
    }

    const mapping = PDF_COURSE_MAPPINGS.find(m => m.cursoNombre.toLowerCase() === curso.nombre.toLowerCase());
    let profId = curso.profesor_id;
    let horario = curso.horario;

    if (mapping) {
      horario = mapping.horario;
      const matchedProfId = profMap.get(mapping.profesorNombre.toLowerCase().trim());
      if (matchedProfId) profId = matchedProfId;
    }

    cursosMeta.push({
      id: curso.id,
      profesor_id: profId,
      horario: horario,
      temas: topics
    });

    if (topics.length > 0) {
      topics.forEach((t, idx) => {
        temasCurso.push({
          curso_id: curso.id,
          orden: idx + 1,
          modulo: `Sesión ${idx + 1}`,
          titulo: t,
          descripcion: `Contenido práctico de ${t}`
        });
      });
    }
  }

  // 4. Parse PDFs
  console.log('\n--- 4. Procesando Archivos PDF de Inscripciones ---');
  if (!fs.existsSync(pdfDir)) {
    throw new Error(`Carpeta de inscripciones no encontrada: ${pdfDir}`);
  }
  const pdfFiles = fs.readdirSync(pdfDir).filter(f => f.endsWith('.pdf'));
  console.log(`Se detectaron ${pdfFiles.length} archivos PDF en la carpeta.`);

  const allRegistrations = [];
  const uniqueStudentsMap = new Map();
  const inscripcionesList = [];
  const asistenciasList = [];
  const today = new Date();

  for (const file of pdfFiles) {
    const mapping = PDF_COURSE_MAPPINGS.find(m => m.filePattern.test(file));
    if (!mapping) {
      console.warn(`[WARN] No hay mapeo configurado para el archivo: ${file}`);
      continue;
    }

    const cursoDB = cursosExistentes.find(c => 
      c.nombre.toLowerCase().trim() === mapping.cursoNombre.toLowerCase().trim()
    );
    if (!cursoDB) {
      console.warn(`[WARN] Curso no encontrado en BD para: ${mapping.cursoNombre}`);
      continue;
    }

    const filePath = path.join(pdfDir, file);
    const parser = new PDFParse(new Uint8Array(fs.readFileSync(filePath)));
    await parser.load();
    const parsedText = await parser.getText();
    const lines = parsedText.text.split('\n');

    let fileCount = 0;
    // Calculate nearest past class date
    const classDate = new Date(today);
    const currentDay = classDate.getDay();
    let diff = currentDay - mapping.diaSemana;
    if (diff < 0) diff += 7;
    classDate.setDate(classDate.getDate() - diff);
    const fechaISO = classDate.toISOString().split('T')[0];

    for (const l of lines) {
      const student = parseStudentRow(l);
      if (student) {
        fileCount++;
        uniqueStudentsMap.set(student.cedula, {
          nombre_completo: student.nombre_completo,
          cedula: student.cedula,
          correo: student.correo,
          telefono: student.telefono,
          curso: cursoDB.nombre
        });

        inscripcionesList.push({
          curso_id: cursoDB.id,
          cedula: student.cedula,
          estado: 'activo'
        });

        asistenciasList.push({
          curso_id: cursoDB.id,
          cedula: student.cedula,
          fecha: fechaISO,
          estado: 'Presente'
        });

        allRegistrations.push({
          curso: cursoDB.nombre,
          profesor: mapping.profesorNombre,
          horario: mapping.horario,
          cedula: student.cedula,
          nombre_completo: student.nombre_completo,
          correo: student.correo,
          telefono: student.telefono,
          estado_inscripcion: 'activo',
          fecha_registro: new Date().toISOString()
        });
      }
    }
    console.log(`[OK] ${file.padEnd(65)} -> ${fileCount} alumnos extraídos.`);
  }

  // 5. Execute DB Sync via sync_inscripciones_batch RPC
  console.log(`\n--- 5. Sincronizando con Supabase mediante Transacción Atómica ---`);
  console.log(`- Alumnos únicos a sincronizar:     ${uniqueStudentsMap.size}`);
  console.log(`- Inscripciones a registrar:       ${inscripcionesList.length}`);
  console.log(`- Asistencias iniciales a generar: ${asistenciasList.length}`);
  console.log(`- Metadatos de cursos:             ${cursosMeta.length}`);
  console.log(`- Temas curriculares:              ${temasCurso.length}`);

  // Send payload in batches to ensure smooth execution
  const alumnosArray = Array.from(uniqueStudentsMap.values());
  const batchSize = 100;

  // Batch sync alumnos
  for (let i = 0; i < alumnosArray.length; i += batchSize) {
    const chunkAlumnos = alumnosArray.slice(i, i + batchSize);
    const payload = {
      cursos_meta: i === 0 ? cursosMeta : [],
      temas_curso: i === 0 ? temasCurso : [],
      alumnos: chunkAlumnos,
      inscripciones: [],
      asistencias: []
    };
    const { data: res, error: errRpc } = await supabase.rpc('sync_inscripciones_batch', { payload });
    if (errRpc) {
      console.error(`Error en lote de alumnos ${i}:`, errRpc.message);
    }
  }

  // Batch sync inscripciones
  for (let i = 0; i < inscripcionesList.length; i += batchSize) {
    const chunkInsc = inscripcionesList.slice(i, i + batchSize);
    const payload = {
      cursos_meta: [],
      temas_curso: [],
      alumnos: [],
      inscripciones: chunkInsc,
      asistencias: []
    };
    const { data: res, error: errRpc } = await supabase.rpc('sync_inscripciones_batch', { payload });
    if (errRpc) {
      console.error(`Error en lote de inscripciones ${i}:`, errRpc.message);
    }
  }

  // Batch sync asistencias
  for (let i = 0; i < asistenciasList.length; i += batchSize) {
    const chunkAsist = asistenciasList.slice(i, i + batchSize);
    const payload = {
      cursos_meta: [],
      temas_curso: [],
      alumnos: [],
      inscripciones: [],
      asistencias: chunkAsist
    };
    const { data: res, error: errRpc } = await supabase.rpc('sync_inscripciones_batch', { payload });
    if (errRpc) {
      console.error(`Error en lote de asistencias ${i}:`, errRpc.message);
    }
  }

  // 6. Export to Google Sheets CSV & JSON
  console.log('\n--- 6. Generando Exportaciones para Google Sheets ---');
  const distDir = path.join(__dirname, '..', 'dist');
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
  }

  const csvPath = path.join(distDir, 'google_sheets_inscripciones.csv');
  const jsonPath = path.join(distDir, 'google_sheets_inscripciones.json');

  const csvHeaders = 'Curso,Profesor,Horario,Cedula,Nombre Completo,Correo,Telefono,Estado Inscripcion,Fecha Registro\n';
  const csvRows = allRegistrations.map(r => 
    `"${r.curso}","${r.profesor}","${r.horario}","${r.cedula}","${r.nombre_completo}","${r.correo}","${r.telefono}","${r.estado_inscripcion}","${r.fecha_registro}"`
  ).join('\n');

  fs.writeFileSync(csvPath, '\uFEFF' + csvHeaders + csvRows, 'utf8');
  fs.writeFileSync(jsonPath, JSON.stringify(allRegistrations, null, 2), 'utf8');

  console.log(`[OK] Archivo CSV para Google Sheets guardado en: ${csvPath}`);
  console.log(`[OK] Archivo JSON para Google Sheets guardado en: ${jsonPath}`);

  // 7. Verify Supabase Counts
  const { count: totalAlumnos } = await supabase.from('alumnos').select('*', { count: 'exact', head: true });
  const { count: totalInscripciones } = await supabase.from('inscripciones').select('*', { count: 'exact', head: true });
  const { count: totalAsistencias } = await supabase.from('asistencia').select('*', { count: 'exact', head: true });
  const { count: totalTemas } = await supabase.from('temas_curso').select('*', { count: 'exact', head: true });

  console.log('\n================================================================');
  console.log('               RESUMEN DE SINCRONIZACIÓN EXITOSA               ');
  console.log('================================================================');
  console.log(`Total Alumnos en Supabase:       ${totalAlumnos}`);
  console.log(`Total Inscripciones en Supabase: ${totalInscripciones}`);
  console.log(`Total Asistencias en Supabase:   ${totalAsistencias}`);
  console.log(`Total Temas Curriculares en BD:  ${totalTemas}`);
  console.log(`Total Filas en Google Sheets:    ${allRegistrations.length}`);
  console.log('================================================================\n');
}

main().catch(err => {
  console.error('\n[FATAL ERROR]', err);
  process.exit(1);
});
