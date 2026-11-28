-- ============================================================================
-- MIGRACIÓN: Incorporación de Cursos y Temas de Formación IMMUJER 2026
-- Archivo: 20261127231500_add_immujer_2026_cursos_y_temas.sql
-- Proyecto: UMBRAL - IMMUJER
-- ============================================================================

DO $$
DECLARE
    v_curso RECORD;
    v_curso_id UUID;
    v_idx INT;
    v_tema TEXT;
    v_cursos JSONB := '[
        {
            "nombre": "Contabilidad Básica",
            "descripcion": "Formación IMMUJER 2026: Fundamentos contables, partida doble, libros de registro, estados financieros, depreciación, amortización e inventarios.",
            "temas": [
                "Definición e importancia de la contabilidad",
                "Tipos de cuentas. El debe, el haber y el saldo",
                "Concepto y ejemplo de la partida doble",
                "La cuenta «T»",
                "Naturaleza de las cuentas: aumento y disminución",
                "Definición y ejemplo de cuentas reales y nominales",
                "La ecuación patrimonial contable",
                "El estado de comprobación, ejemplos",
                "El estado de resultados, ejemplos",
                "El estado de situación financiera, ejemplos",
                "Libros de registros contables: diario, mayor, inventario",
                "Ejercicios de asientos de diario y pases al mayor",
                "Asientos de ajustes y cierre de ejercicio económico",
                "Concepto, tipos y ejemplo de depreciación y amortización",
                "Tipos de inventario de mercancía y cálculo del costo de venta"
            ]
        },
        {
            "nombre": "Diseño de Cejas y Pestañas",
            "descripcion": "Formación IMMUJER 2026: Visagismo, diseño, simetría, colorimetría, pigmentos, higiene y prácticas de epilación de cejas.",
            "temas": [
                "Epilación de cejas.",
                "Tipos de rostro.",
                "Práctica de identificación.",
                "Tipos de cejas.",
                "Identificación de Tipos de rostros y tipos de cejas.",
                "Visagismo.",
                "Diseño de cejas.",
                "Práctica de visagismo.",
                "Cejas asimétricas.",
                "App de simetría.",
                "Cejas depilatorias.",
                "Proceso de Epilación de cejas.",
                "Colorimetria.",
                "Pigmentos.",
                "Higiene.",
                "Prácticas de diseño y epilación de cejas."
            ]
        },
        {
            "nombre": "Manicurista Básico",
            "descripcion": "Formación IMMUJER 2026: Fundamentos de manicura básica, esmaltado semipermanente, base rubber, builder gel y polygel.",
            "temas": [
                "Introducción a la materia",
                "Fundamentos Teóricos de la Manicura Básica",
                "Práctica I: Preparación y Limpieza Profunda de la Uña Natural",
                "Práctica II: Esmaltado Semipermanente",
                "Práctica III: Nivelación con Base Rubber (Módulo 1)",
                "Práctica IV: Nivelación con Base Rubber (Módulo 2)",
                "Práctica V: Gel Constructor (Builder Gel) sobre Uña Natural",
                "Práctica VI: Extensión de Uñas con Builder Gel y Moldes Dual",
                "Práctica VII: Recubrimiento con Polygel sobre Uña Natural",
                "Práctica VIII: Extensión de Uñas con Polygel y Moldes Dual",
                "Evaluación General: Examen Teórico-Práctico"
            ]
        },
        {
            "nombre": "Peluquería",
            "descripcion": "Formación IMMUJER 2026: Anatomía capilar, protocolos sanitarios, colorimetría, corte, alisados, ondas, alta peluquería y gestión del salón.",
            "temas": [
                "Ética y Atención: Imagen profesional, comunicación asertiva y elaboración de la ficha técnica del cliente.",
                "Protocolos Sanitarios: Esterilización (química y física), prevención de enfermedades cutáneas y postura ergonómica para evitar lesiones laborales.",
                "Anatomía y Fisiología del cabello: Estructura de la hebra (cutícula, córtex, médula) y del folículo piloso.",
                "Ciclo de Vida Capilar: Las tres fases fundamentales: Anágena (crecimiento), Catágena (transición) y Telógena (caída).",
                "Propiedades Físicas: Conceptos de permeabilidad, resistencia, elasticidad y porosidad.",
                "Estructurales: Puntas abiertas (tricoptilosis) o nudos (tricorrexis nudosa).",
                "Cuero cabelludo: Diferenciar entre pitiriasis (caspa), seborrea y sensibilidad.",
                "Tipologías: Clasificación según forma (lisótrico, cinótrico, ulótrico) y emulsión epicutánea (seco, normal, mixto).",
                "Mantenimiento de Equipo: Lubricación de máquinas y afilado de tijeras.",
                "Diferencia entre cepillos térmicos, de cerdas naturales y sintética.",
                "Protocolo de Lavado: Temperatura del agua, ergonomía en el lava-cabeza y técnicas de digitopresión para masajes relajantes.",
                "Brushing y Acabado: Manejo de la boquilla del secador, control del friz y sellado de puntas con aire frío.",
                "Química del Color: Volúmenes de peróxido (10, 20, 30, 40) y su acción en la corteza. Formulación de mezclas (1+1, 1+1.5 y 1+2).",
                "Técnicas de Iluminación: Diagramación de la cabeza para mechas, tricotado, tizado y airt touch de secciones y control visual de la etapa de aclaración.",
                "Arquitectura del Corte: Grados de elevación (0°, 45°, 90°, 135°, 180°).",
                "Proyección y distribución del cabello. Cortes Femeninos: Técnicas de encapado, diseño de flequillos y simetría en cortes",
                "Alisados: queratinas y diferencias de las aplicaciones de acuerdo a las marcas más conocidas del mercado",
                "Manejo de humos y temperaturas de planchado",
                "Arte de las ondas: La química del marcado, Diagnostico y preparación, temperatura correcta, técnicas, herramientas, movimiento, ondas con pinzas, ondas planchas, ondas con rizador",
                "Alta peluquería: Técnicas de anclaje para tocados de novia y pulido de moños altos",
                "Finanzas: Cálculo del \"costo por gramo\" de producto. Punto de equilibrio para abrir un salón o trabajar a domicilio.",
                "Marketing Visual: Planificación de contenido y compresión del algoritmo",
                "Fidelización: Estrategias de seguimiento de clientes y promociones temporadas"
            ]
        },
        {
            "nombre": "Marketing Digital",
            "descripcion": "Formación IMMUJER 2026: Estrategia en redes sociales, diseño gráfico en Canva, uso de IA con Gemini, Reels, Meta Business Suite y WhatsApp.",
            "temas": [
                "Introducción + Definir objetivos de RRSS",
                "Uso y configuración de Gemini para crear contenido",
                "Normas de diseño",
                "Psicología y uso del color al momento de crear las piezas gráficas",
                "Primera práctica con Canva",
                "Práctica en Canva + Gemini configurado",
                "Aplicar la teoría, diseñaremos un carrusel en Canva",
                "Subir todos los recursos de nuestra marca a Canva",
                "Asesoría para cada alumno y práctica",
                "Explicación de los formatos y sus usos + Hacer un post",
                "Seguimiento a creación de las piezas + Responder dudas de la clase",
                "Gemini II: Optimiza tu flujo de trabajo",
                "Práctica + Seguimiento de piezas gráficas",
                "Asesoría + Práctica (Crear una pieza de cada...)",
                "Explicación de formato Reel y cómo hacer uno",
                "Jornada de asesoría y seguimiento a cada uno de los alumnos",
                "Continuación de uso de CapCut/Edits para hacer Reels",
                "Frecuencias de publicación y contenido orgánico",
                "Introducción a Meta Business Suite",
                "Jornada de seguimiento y asesoría a las alumnas",
                "Seguimiento de las piezas gráficas + Uso de las herramientas aprendidas en clase",
                "Estadísticas de Meta, qué son y cómo interpretarlas",
                "Feedback de los alumnos: Breve exposición de su trabajo y de cómo les ha ido con el curso",
                "Cómo utilizar WhatsApp como una herramienta favorable y complementaria para las RRSS",
                "Planificación en Meta del contenido ya trabajado en el curso: Contenido",
                "Seguimiento de piezas gráficas + Asesoría",
                "Breve explicación de cómo funciona la publicidad paga + Actividad final para compartir"
            ]
        },
        {
            "nombre": "Asistente de Farmacia",
            "descripcion": "Formación IMMUJER 2026: Gestión farmacéutica, legislación sanitaria, buenas prácticas de almacenaje y dispensación, farmacología y materiales médico-quirúrgicos.",
            "temas": [
                "Fomentando Cultura",
                "Conociendo La Farmacia",
                "Concepto",
                "Reseña",
                "Símbolo",
                "Tipos",
                "Medicamentos: Tipos, RX, OTC",
                "Ley De Medicamentos",
                "Ley Orgánica De Drogas",
                "Ley Orgánica De Drogas Resumen",
                "Productos De Importación",
                "Buenas Prácticas De Almacenaje (BPA), Inventarios",
                "Buenas Prácticas De Distribución (BPD)",
                "Buenas Prácticas De Almacenamiento (BPA)",
                "Buenas Prácticas De Dispensación (BPD)",
                "Formas Farmacéuticas",
                "Características De Los Fármacos",
                "Terminologías",
                "Farmacoterapéutica Clase ATC",
                "Manejo De Dosis Terapéuticas",
                "Conociendo Materiales Médico Quirúrgicos Y Equipos"
            ]
        },
        {
            "nombre": "Etiqueta y Protocolo",
            "descripcion": "Formación IMMUJER 2026: Códigos de etiqueta, comunicación, protocolo social, empresarial, institucional y seguridad de eventos.",
            "temas": [
                "Etiqueta",
                "Principios Básicos De La Etiqueta En Lo Social, Empresarial E Institucional U Oficial",
                "Clasificación De La Etiqueta",
                "Códigos De Etiqueta",
                "Presentación",
                "Saludos",
                "Usos Del \"Usted Y Tú\"",
                "Comunicación Verbal",
                "Protocolo",
                "Principios Básicos Del Protocolo En Lo Social, Empresarial E Institucional U Oficial",
                "Categorías De Protocolo",
                "Clasificación Del Protocolo Según Su Conformación, Categoría Y Tipo De Evento:",
                "a. Protocolo Social:",
                "b. Protocolo Empresarial:",
                "c. Protocolo Institucional U Oficial",
                "d. Protocolo y Seguridad De Eventos"
            ]
        },
        {
            "nombre": "Oratoria",
            "descripcion": "Formación IMMUJER 2026: Comunicación efectiva, respiración consciente, manejo del miedo escénico, expresión corporal, improvisación y storytelling.",
            "temas": [
                "Elementos básicos de la Oratoria y de la comunicación",
                "Técnicas de respiración consciente",
                "Lectoescritura",
                "Identificar el miedo y controlarlo",
                "Optimizar la modulación, vocalización y prácticas para mejorar el tono de voz y la proyección",
                "Fortalecimiento de la presencia en actividades grupales",
                "Creación de discursos de impacto",
                "Los verbos aliados para comunicar y conversar sin barreras",
                "La oratoria como expresión de una comunicación efectiva",
                "Conexión emocional e intelectual con la audiencia",
                "Expresión corporal",
                "Técnicas de teatro",
                "Improvisación y persuasión",
                "Cómo contar historias (Storytelling) y transmitir ideas de manera eficaz"
            ]
        },
        {
            "nombre": "Decoración con Globos",
            "descripcion": "Formación IMMUJER 2026: Diseño y armado de estructuras decorativas navideñas con globos (pilares, arcos, guirnaldas, centros de mesa y murales).",
            "temas": [
                "Pilares navideños básicos",
                "Arco de Globo navideño",
                "Árbol de navidad",
                "Bambalinas en Globos",
                "Centro de Mesa navideño en globos",
                "Regalos navideños en Globos",
                "Campanas navideñas en Globos",
                "Muñeco de Nieve Navideño",
                "Guirnalda Navideña en globos",
                "Bastones navideños",
                "Mural de globos navideño"
            ]
        },
        {
            "nombre": "Pintura Artística",
            "descripcion": "Formación IMMUJER 2026: Curso de Pintura Artística.",
            "temas": []
        },
        {
            "nombre": "Bisutería",
            "descripcion": "Formación IMMUJER 2026: Elaboración de accesorios artesanales en hilo elástico, rígido, macramé, nudo franciscano, mostacillas y cristales.",
            "temas": [
                "Herramientas básicas de la bisutería, pulsera elástica y pulsera rígida",
                "Collar elástico, collar fantasma y collar rígido",
                "Bolas chicles (hilo chino e hilo rígido) y pulsera con dijes",
                "Llaveros, bolígrafos y lápiz",
                "Strap para celular y strap para bolsos",
                "Pulseras macramé plano, pulsera nudo ajustable y pulsera nudo corredizo",
                "Pulsera macramé con dije y pulsera macramé con cuentas por fuera / por dentro",
                "Pulsera macramé espiral y pulsera macramé con cruz",
                "Pulsera nudo franciscano y pulsera nudo franciscano con dijes y cuentas",
                "Collar de flores en mostacillas / cristales / balines",
                "Juego de pulseras y combinaciones, set de pulseras",
                "Tobilleras, pulseras para hombres y cierre"
            ]
        }
    ]'::jsonb;
BEGIN
    FOR v_curso IN SELECT * FROM jsonb_array_elements(v_cursos)
    LOOP
        SELECT id INTO v_curso_id
        FROM public.cursos
        WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(v_curso.value->>'nombre'))
        LIMIT 1;

        IF v_curso_id IS NULL THEN
            INSERT INTO public.cursos (
                nombre,
                descripcion,
                estado,
                cupo_maximo,
                admision_abierta,
                temas
            ) VALUES (
                v_curso.value->>'nombre',
                v_curso.value->>'descripcion',
                'activo',
                30,
                true,
                v_curso.value->'temas'
            )
            RETURNING id INTO v_curso_id;
        ELSE
            UPDATE public.cursos
            SET temas = v_curso.value->'temas',
                updated_at = now()
            WHERE id = v_curso_id;
        END IF;

        v_idx := 0;
        FOR v_tema IN SELECT jsonb_array_elements_text(v_curso.value->'temas')
        LOOP
            v_idx := v_idx + 1;
            INSERT INTO public.temas_curso (
                curso_id,
                orden,
                titulo
            )
            SELECT v_curso_id, v_idx, v_tema
            WHERE NOT EXISTS (
                SELECT 1 FROM public.temas_curso
                WHERE curso_id = v_curso_id
                  AND (orden = v_idx OR LOWER(TRIM(titulo)) = LOWER(TRIM(v_tema)))
            );
        END LOOP;
    END LOOP;
END $$;
