"use client";

import { FormEvent, MouseEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import styles from "./admin.module.css";

type Role = "director" | "subdirector" | "tutor" | "profesor" | "alumno";
type View = "resumen" | "colegio" | "secciones" | "materias" | "usuarios" | "materiales" | "preguntas" | "tareas" | "batallas" | "progreso" | "auditoria";
type Section = { grade: string; letter: string; tutor: string; students: number; active: boolean };
type Material = { name: string; subject: string; owner: string; size: string; status: string; questions: number };
type Question = { id: number; subject: string; text: string; approved: boolean };
type ModalKind = "school" | "subject" | "user" | "import" | "task" | "rank" | "detail" | "export";
type ModalState = { kind: ModalKind; title: string; subtitle: string };
type GeneratedInfo = { source: string; summary: string; topics: string[]; questions: number; tasks: number };

const roleNames: Record<Role, string> = { director: "Director", subdirector: "Subdirector", tutor: "Tutor de aula", profesor: "Profesor", alumno: "Alumno" };
const nav: { id: View; code: string; label: string; roles: Role[] }[] = [
  { id: "resumen", code: "01", label: "Centro de mando", roles: ["director","subdirector","tutor","profesor","alumno"] },
  { id: "colegio", code: "02", label: "Entidad colegio", roles: ["director","subdirector"] },
  { id: "secciones", code: "03", label: "Secciones y aulas", roles: ["director","subdirector","tutor","profesor"] },
  { id: "materias", code: "04", label: "Cursos y materias", roles: ["director","subdirector","tutor","profesor"] },
  { id: "usuarios", code: "05", label: "Usuarios y permisos", roles: ["director","subdirector","tutor"] },
  { id: "materiales", code: "06", label: "Materiales e IA", roles: ["director","subdirector","tutor","profesor"] },
  { id: "preguntas", code: "07", label: "Banco de preguntas", roles: ["director","subdirector","tutor","profesor"] },
  { id: "tareas", code: "08", label: "Tareas", roles: ["director","subdirector","tutor","profesor","alumno"] },
  { id: "batallas", code: "09", label: "Batallas y torneos", roles: ["director","subdirector","tutor","profesor","alumno"] },
  { id: "progreso", code: "10", label: "Rangos, clanes y XP", roles: ["director","subdirector","tutor","profesor","alumno"] },
  { id: "auditoria", code: "11", label: "Actividad y auditoría", roles: ["director","subdirector"] },
];

const seedSections: Section[] = [
  { grade: "6.º Primaria", letter: "A", tutor: "Lucía Vargas", students: 28, active: true },
  { grade: "6.º Primaria", letter: "B", tutor: "Marco Salas", students: 27, active: true },
  { grade: "5.º Primaria", letter: "A", tutor: "Andrea Núñez", students: 30, active: true },
  { grade: "5.º Primaria", letter: "B", tutor: "Sin asignar", students: 25, active: false },
];
const seedMaterials: Material[] = [
  { name: "Fracciones equivalentes.pdf", subject: "Matemática", owner: "Diego Ramos", size: "3.2 MB", status: "Listo", questions: 100 },
  { name: "El sistema solar.pptx", subject: "Ciencia", owner: "Ana Torres", size: "8.7 MB", status: "Listo", questions: 84 },
  { name: "Tipos de texto.docx", subject: "Comunicación", owner: "Lucía Vargas", size: "1.4 MB", status: "Procesando", questions: 0 },
];
const seedQuestions: Question[] = [
  { id: 1, subject: "Matemática", text: "¿Qué fracción es equivalente a 3/4?", approved: true },
  { id: 2, subject: "Ciencia", text: "¿Cuál es el planeta más cercano al Sol?", approved: false },
  { id: 3, subject: "Comunicación", text: "¿Qué función cumple el conector «sin embargo»?", approved: false },
  { id: 4, subject: "Personal Social", text: "¿En qué región se desarrolló la cultura Moche?", approved: true },
];

function Castle({ violet = false }: { violet?: boolean }) {
  return <div className={`${styles.castle} ${violet ? styles.violet : ""}`} aria-hidden="true"><i/><i/><i/><span/><b/></div>;
}
function Badge({ children, tone = "plain" }: { children: React.ReactNode; tone?: string }) {
  return <span className={`${styles.badge} ${styles[`badge_${tone}`] || ""}`}>{children}</span>;
}
function Header({ overline, title, text, action }: { overline: string; title: string; text: string; action?: React.ReactNode }) {
  return <header className={styles.viewHeader}><div><span>{overline}</span><h1>{title}</h1><p>{text}</p></div>{action}</header>;
}

export default function AdminPage() {
  const [logged, setLogged] = useState(false);
  const [role, setRole] = useState<Role>("director");
  const [view, setView] = useState<View>("resumen");
  const [menu, setMenu] = useState(false);
  const [notice, setNotice] = useState("Modo presentación: no modifica datos reales del colegio.");
  const [sections, setSections] = useState(seedSections);
  const [sectionForm, setSectionForm] = useState(false);
  const [materials, setMaterials] = useState(seedMaterials);
  const [questions, setQuestions] = useState(seedQuestions);
  const [generated, setGenerated] = useState<GeneratedInfo | null>(null);
  const [modal, setModal] = useState<ModalState | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!modal) return;
    const closeOnEscape = (event: KeyboardEvent) => { if (event.key === "Escape") setModal(null); };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [modal]);

  const login = (event: FormEvent) => { event.preventDefault(); setLogged(true); setNotice(`Sesión demo iniciada como ${roleNames[role]}.`); };
  const changeRole = (next: Role) => { setRole(next); setView("resumen"); setNotice(`Permisos actualizados para la vista ${roleNames[next]}.`); };
  const createSection = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); const data = new FormData(event.currentTarget);
    const grade = String(data.get("grade")); const letter = String(data.get("letter")).toUpperCase();
    setSections(current => [...current, { grade, letter, tutor: "Sin asignar", students: 0, active: true }]); setSectionForm(false); setNotice(`${grade} Sección ${letter} agregada al borrador.`);
  };
  const upload = (files: FileList | null) => {
    if (!files?.length) return;
    const added = Array.from(files).map(file => ({ name: file.name, subject: "Por clasificar", owner: roleNames[role], size: `${Math.max(.1,file.size/1048576).toFixed(1)} MB`, status: "Analizando", questions: 0 }));
    setMaterials(current => [...added,...current]); setNotice(`${added.length} archivo(s) recibido(s). El agente está preparando un borrador.`);
    const source = added[0].name;
    window.setTimeout(() => {
      setMaterials(current => current.map(item => added.some(uploaded => uploaded.name === item.name) ? { ...item, status: "Borrador IA", questions: 12 } : item));
      setGenerated({ source, summary: `El material «${source.replace(/\.[^.]+$/, "")}» presenta conceptos para una sesión guiada, ejemplos de aplicación y criterios de comprobación. Este texto es una simulación para la presentación.`, topics: ["Conceptos principales", "Ejemplos aplicados", "Errores frecuentes", "Reto de cierre"], questions: 12, tasks: 2 });
      setQuestions(current => [...current, { id: Date.now(), subject: "Por clasificar", text: `¿Cuál es la idea principal desarrollada en «${source.replace(/\.[^.]+$/, "")}»?`, approved: false }, { id: Date.now()+1, subject: "Por clasificar", text: "¿Qué ejemplo aplica correctamente el concepto explicado en el material?", approved: false }]);
      setNotice(`Borrador simulado listo: 12 preguntas y 2 propuestas de tarea creadas desde ${source}.`);
    }, 900);
  };
  const openModalFromButton = (event: MouseEvent<HTMLDivElement>) => {
    const button = (event.target as HTMLElement).closest("button");
    if (!button) return;
    const label = button.textContent?.replace(/\s+/g," ").trim() || "";
    const actions: Record<string, ModalState> = {
      "GUARDAR CAMBIOS": { kind:"school", title:"Confirmar configuración", subtitle:"Revisa los datos institucionales antes de guardar el borrador." },
      "AÑADIR MATERIA": { kind:"subject", title:"Nueva materia", subtitle:"Define el curso, color del nodo y responsable académico." },
      "NUEVO USUARIO": { kind:"user", title:"Crear usuario", subtitle:"Genera credenciales y asigna el alcance del nuevo perfil." },
      "IMPORTAR CSV": { kind:"import", title:"Importar estudiantes", subtitle:"Simula la carga masiva de una nómina para una sección." },
      "GENERAR BORRADOR": { kind:"detail", title:"Generación asistida", subtitle:"Selecciona banco, materia y cantidad para crear un lote de demostración." },
      "CREAR TAREA": { kind:"task", title:"Nueva tarea", subtitle:"Configura una misión académica y la recompensa de experiencia." },
      "CONFIGURAR RANGOS": { kind:"rank", title:"Configurar rangos", subtitle:"Ajusta los umbrales institucionales de experiencia." },
      "EXPORTAR REGISTRO": { kind:"export", title:"Exportar auditoría", subtitle:"Prepara un registro de actividad para dirección." },
      "EDITAR": { kind:"user", title:"Editar permisos", subtitle:"Modifica el rol y el alcance del usuario seleccionado." },
      "CONFIGURAR": { kind:"subject", title:"Configurar materia", subtitle:"Ajusta docente, secciones, color y banco de preguntas." },
      "VER DETALLE": { kind:"detail", title:"Detalle de batalla", subtitle:"Consulta participantes, turnos, nodos conquistados y resultado." },
      "DETALLE": { kind:"detail", title:"Detalle de actividad", subtitle:"Consulta el registro completo de esta acción institucional." },
      "ABRIR SECCIÓN": { kind:"detail", title:"Detalle de sección", subtitle:"Consulta estudiantes, tutor, materias activas y progreso del aula." },
    };
    if (actions[label]) setModal(actions[label]);
  };
  const completeModal = (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); const title=modal?.title || "Registro"; setModal(null); setNotice(`${title}: información ficticia guardada correctamente para la presentación.`); };

  if (!logged) return <main className={styles.login}>
    <div className={styles.scan}/><Link href="/">VOLVER A LA LANDING</Link>
    <section className={styles.loginShell}>
      <div className={styles.loginScene}><span>CONSOLA INSTITUCIONAL</span><div className={styles.route}><Castle/><i/><b>MAT</b><i/><b>CIE</b><i/><Castle violet/></div><div className={styles.heroLogo} role="img" aria-label="BattleGraph"/><p>Configura el colegio. Despliega las aulas. Convierte el aprendizaje en territorio.</p><dl><div><dt>05</dt><dd>ROLES</dd></div><div><dt>11</dt><dd>MÓDULOS</dd></div><div><dt>01</dt><dd>COLEGIO</dd></div></dl></div>
      <form className={styles.loginForm} onSubmit={login}><Brand/><span>ACCESO DE PRESENTACIÓN</span><h2>ENTRAR AL PANEL</h2><p>Elige un perfil para recorrer sus vistas y permisos.</p><label>PERFIL<select value={role} onChange={e=>setRole(e.target.value as Role)}>{Object.entries(roleNames).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label><label>CORREO<input type="email" defaultValue="director@battlegraf.demo" required/></label><label>CONTRASEÑA<input type="password" defaultValue="demo2026" required/></label><button type="submit">INICIAR SESIÓN <small>ENTER</small></button><aside><strong>DEMO</strong><span>director@battlegraf.demo<br/>Clave: demo2026</span></aside></form>
    </section>
  </main>;

  const current = nav.find(item=>item.id===view)?.label || "Centro de mando";
  return <main className={styles.app}><div className={styles.scan}/>
    <aside className={`${styles.sidebar} ${menu ? styles.open : ""}`}><Brand/><div className={styles.school}><Castle/><div><small>ENTIDAD ACTIVA</small><strong>I.E. Horizonte</strong><span>Código 1048576</span></div></div><nav><small>NAVEGACIÓN</small>{nav.filter(item=>item.roles.includes(role)).map(item=><button className={item.id===view?styles.active:""} key={item.id} onClick={()=>{setView(item.id);setMenu(false)}}><span>{item.code}</span>{item.label}</button>)}</nav><footer><span>CONFIGURACIÓN</span><i><b/></i><strong>82% LISTO</strong><button onClick={()=>setLogged(false)}>CERRAR SESIÓN</button></footer></aside>
    <section className={styles.workspace}><header className={styles.topbar}><button className={styles.menuButton} onClick={()=>setMenu(!menu)}>MENU</button><div><small>CONSOLA / {current.toUpperCase()}</small><strong>{current}</strong></div><label>BUSCAR<input placeholder="Alumno, sección, material..."/></label><div><small>VISTA DE ROL</small><select value={role} onChange={e=>changeRole(e.target.value as Role)}>{Object.entries(roleNames).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select><b>{roleNames[role].slice(0,2).toUpperCase()}</b></div></header>
      {notice&&<div className={styles.notice} role="status"><i/>{notice}<button onClick={()=>setNotice("")}>CERRAR</button></div>}
      <div className={styles.content} onClickCapture={openModalFromButton}>
        {view==="resumen"&&<Dashboard role={role} go={setView}/>} {view==="colegio"&&<SchoolView/>}
        {view==="secciones"&&<Sections sections={sections} form={sectionForm} toggle={()=>setSectionForm(!sectionForm)} create={createSection}/>} {view==="materias"&&<Subjects/>} {view==="usuarios"&&<Users/>}
        {view==="materiales"&&<Materials materials={materials} generated={generated} choose={()=>fileInput.current?.click()} inspect={material=>setModal({kind:"detail",title:material.name,subtitle:`${material.questions} preguntas · ${material.status}`})}/>} {view==="preguntas"&&<Questions questions={questions} approve={id=>{setQuestions(current=>current.map(q=>q.id===id?{...q,approved:true}:q));setNotice("Pregunta aprobada y habilitada para futuros grafos.")}}/>}
        {view==="tareas"&&<Tasks student={role==="alumno"}/>} {view==="batallas"&&<Battles/>} {view==="progreso"&&<Progress student={role==="alumno"}/>} {view==="auditoria"&&<Audit/>}
      </div>
    </section><input className={styles.hidden} ref={fileInput} type="file" multiple accept=".pdf,.ppt,.pptx,.doc,.docx,.txt,.png,.jpg,.jpeg" onChange={e=>upload(e.target.files)}/>{modal&&<DemoModal modal={modal} close={()=>setModal(null)} complete={completeModal}/>}
  </main>;
}

function Brand(){return <Link className={styles.brand} href="/" aria-label="BattleGraph"><span className={styles.brandLogo}/></Link>}

function Dashboard({role,go}:{role:Role;go:(v:View)=>void}){
  const student=role==="alumno"; const stats=student?[["RANGO","ESTRATEGA II","+240 XP"],["TAREAS","03","1 vence hoy"],["BATALLAS","12","8 victorias"],["CLAN","LOS QUIPUS","2.º lugar"]]:[["ESTUDIANTES","110","+8 este mes"],["SECCIONES","04","3 activas"],["PREGUNTAS","384","16 por revisar"],["BATALLAS","128","+24 esta semana"]];
  return <><Header overline="ESTADO GENERAL" title={`BIENVENIDO, ${roleNames[role].toUpperCase()}`} text={student?"Tu progreso, tareas y batallas en un solo lugar.":"Control institucional, académico y lúdico desde una sola consola."} action={<button className={styles.primary} onClick={()=>go(student?"batallas":"secciones")}>{student?"BUSCAR BATALLA":"CONTINUAR CONFIGURACIÓN"}</button>}/><div className={styles.metrics}>{stats.map(([a,b,c],i)=><article key={a}><span>0{i+1} / {a}</span><strong>{b}</strong><p>{c}</p></article>)}</div><div className={styles.split}><Panel title="RITMO DE APRENDIZAJE" tag="ACTIVIDAD"><div className={styles.chart}>{[35,51,44,72,58,85,67,92].map((h,i)=><i key={i} style={{height:`${h}%`}}/>)}</div></Panel><Panel title="SIGUIENTE MOVIMIENTO" tag="ACCIONES"><div className={styles.actions}>{(student?[["08","Resolver tarea de Matemática","Vence hoy"],["09","Desafiar a 6.º B","Bot disponible"],["10","Revisar mi clan","2 recompensas"]]:[["03","Completar 5.º Primaria B","Falta tutor"],["07","Revisar 16 preguntas","Borrador IA"],["08","Publicar tarea de Ciencia","Guardado"]]).map(([n,a,b])=><button key={a}><span>{n}</span><strong>{a}<small>{b}</small></strong><b>IR</b></button>)}</div></Panel></div><div className={styles.split}><Panel title="MAPA DEL COLEGIO" tag="COBERTURA"><div className={styles.miniMap}><Castle/><i/><b>6A</b><i/><b>6B</b><i/><b>5A</b><i/><Castle violet/></div></Panel><Panel title="ÚLTIMA ACTIVIDAD" tag="EN VIVO"><ul className={styles.timeline}><li>Ana aprobó 12 preguntas <span>8 MIN</span></li><li>6.º A completó una batalla <span>24 MIN</span></li><li>Se publicó “Fracciones” <span>1 H</span></li></ul></Panel></div></>;
}
function Panel({title,tag,children}:{title:string;tag:string;children:React.ReactNode}){return <article className={styles.panel}><header><div><span>{tag}</span><h2>{title}</h2></div></header>{children}</article>}

function SchoolView(){return <><Header overline="NÚCLEO INSTITUCIONAL" title="ENTIDAD COLEGIO" text="Datos maestros, reglas académicas y parámetros generales para toda la comunidad." action={<button className={styles.primary}>GUARDAR CAMBIOS</button>}/><div className={styles.split}><Panel tag="IDENTIDAD" title="DATOS DEL COLEGIO"><div className={styles.formGrid}><label>Nombre<input defaultValue="I.E. Horizonte"/></label><label>Código modular<input defaultValue="1048576"/></label><label>UGEL<input defaultValue="UGEL 07"/></label><label>Región<input defaultValue="Lima Metropolitana"/></label><label className={styles.full}>Dirección<input defaultValue="Av. del Aprendizaje 250"/></label></div></Panel><Panel tag="REGLAS" title="CONFIGURACIÓN DE JUEGO"><div className={styles.settings}>{[["Batallas entre secciones","Permitir A contra B"],["Progreso por tareas","Las entregas otorgan XP"],["Revisión docente obligatoria","La IA no publica sola"],["Turnos de 30 segundos","Tiempo por nodo"]].map(([a,b])=><label key={a}><span><strong>{a}</strong><small>{b}</small></span><input type="checkbox" defaultChecked/></label>)}</div></Panel></div><Panel tag="DESPLIEGUE" title="RUTA DE CONFIGURACIÓN"><div className={styles.steps}>{[["01","COLEGIO","Completo"],["02","SECCIONES","Completo"],["03","PERSONAS","Completo"],["04","CONTENIDO","En curso"],["05","LANZAMIENTO","Pendiente"]].map(x=><div key={x[0]}><span>{x[0]}</span><strong>{x[1]}</strong><small>{x[2]}</small></div>)}</div></Panel></>}

function Sections({sections,form,toggle,create}:{sections:Section[];form:boolean;toggle:()=>void;create:(e:FormEvent<HTMLFormElement>)=>void}){return <><Header overline="ESTRUCTURA ACADÉMICA" title="SECCIONES Y AULAS" text="Cada sección es un territorio con estudiantes, tutor, materias y clanes propios." action={<button className={styles.primary} onClick={toggle}>{form?"CANCELAR":"CREAR SECCIÓN"}</button>}/>{form&&<form className={styles.inlineForm} onSubmit={create}><label>Grado<select name="grade"><option>4.º Primaria</option><option>5.º Primaria</option><option>6.º Primaria</option></select></label><label>Sección<input name="letter" defaultValue="C" maxLength={2}/></label><label>Turno<select><option>Mañana</option><option>Tarde</option></select></label><button className={styles.primary}>AGREGAR</button></form>}<div className={styles.cardGrid}>{sections.map((s,i)=><article className={styles.sectionCard} key={`${s.grade}${s.letter}${i}`}><header><span>SECCIÓN 0{i+1}</span><Badge tone={s.active?"green":"plain"}>{s.active?"ACTIVA":"BORRADOR"}</Badge></header><div className={styles.hex}>{s.letter}</div><h2>{s.grade}</h2><p>Sección {s.letter} · Primaria</p><dl><div><dt>ESTUDIANTES</dt><dd>{s.students}</dd></div><div><dt>TUTOR</dt><dd>{s.tutor}</dd></div><div><dt>MATERIAS</dt><dd>05 activas</dd></div></dl><button>ABRIR SECCIÓN</button></article>)}</div><Panel tag="ENFRENTAMIENTOS" title="CRUCES HABILITADOS"><div className={styles.matches}><div><strong>6.º Primaria A</strong><span>VS</span><strong>6.º Primaria B</strong><Badge tone="violet">HABILITADO</Badge></div><div><strong>5.º Primaria A</strong><span>VS</span><strong>5.º Primaria B</strong><Badge>EN CONFIGURACIÓN</Badge></div></div></Panel></>}

function Subjects(){const rows=[["MAT","Matemática","rojo","100 preguntas","Diego Ramos"],["COM","Comunicación","morado","76 preguntas","Lucía Vargas"],["CIE","Ciencia y Tecnología","cyan","84 preguntas","Ana Torres"],["HIS","Personal Social","dorado","62 preguntas","Marco Salas"],["ART","Arte y Cultura","rosa","40 preguntas","Sin asignar"]];return <><Header overline="NODOS DEL CONOCIMIENTO" title="CURSOS Y MATERIAS" text="Cada color identifica una materia en el grafo. Activa cursos y asigna docentes." action={<button className={styles.primary}>AÑADIR MATERIA</button>}/><div className={styles.subjects}>{rows.map(([code,name,color,count,teacher])=><article data-color={color} key={code}><span>{code}</span><div><small>MATERIA ACTIVA</small><h2>{name}</h2><p>{teacher}</p></div><dl><dt>BANCO</dt><dd>{count}</dd><dt>SECCIONES</dt><dd>3 asignadas</dd></dl><button>CONFIGURAR</button></article>)}</div></>}

function Users(){const rows=[["LV","Lucía Vargas","Tutor","6.º A","Activo"],["DR","Diego Ramos","Profesor","Matemática · 6.º A/B","Activo"],["AT","Ana Torres","Profesor","Ciencia · 5.º/6.º","Activo"],["MS","Marco Salas","Tutor","6.º B","Activo"],["CP","Camila Pérez","Alumno","6.º A","Activo"],["JM","Joaquín Mendoza","Alumno","6.º B","Pendiente"]];return <><Header overline="IDENTIDADES Y ACCESO" title="USUARIOS Y PERMISOS" text="Crea credenciales, asigna alcance y controla qué puede hacer cada rol." action={<div className={styles.buttonGroup}><button>IMPORTAR CSV</button><button className={styles.primary}>NUEVO USUARIO</button></div>}/><div className={styles.roleCards}>{Object.entries(roleNames).map(([key,label],i)=><div key={key}><span>0{i+1}</span><strong>{label}</strong><small>{["1 usuario","1 usuario","2 usuarios","8 usuarios","110 usuarios"][i]}</small></div>)}</div><Panel tag="122 REGISTROS" title="DIRECTORIO INSTITUCIONAL"><div className={styles.table}><header><span>PERSONA</span><span>ROL</span><span>ALCANCE</span><span>ESTADO</span><span>ACCIÓN</span></header>{rows.map(r=><div key={r[1]}><span><i>{r[0]}</i><strong>{r[1]}</strong></span><span>{r[2]}</span><span>{r[3]}</span><Badge tone={r[4]==="Activo"?"green":"gold"}>{r[4]}</Badge><button>EDITAR</button></div>)}</div></Panel></>}

function Materials({materials,generated,choose,inspect}:{materials:Material[];generated:GeneratedInfo|null;choose:()=>void;inspect:(material:Material)=>void}){return <><Header overline="LABORATORIO DE CONTENIDO" title="MATERIALES E IA DOCENTE" text="Carga archivos. La IA propone preguntas y el docente revisa antes de publicar." action={<button className={styles.primary} onClick={choose}>SUBIR ARCHIVOS</button>}/><button className={styles.drop} onClick={choose}><span>PDF · PPTX · DOCX · TXT · PNG · JPG</span><strong>SELECCIONA MATERIAL DE CLASE</strong><small>Máximo 20 MB · espacio privado del colegio</small><b>EXPLORAR EQUIPO</b></button><div className={styles.pipeline}>{[["01","RECIBIDO"],["02","EXTRACCIÓN"],["03","GENERACIÓN IA"],["04","REVISIÓN"],["05","APROBADO"]].map(x=><div key={x[0]}><span>{x[0]}</span><strong>{x[1]}</strong></div>)}</div>{generated&&<section className={styles.generated}><header><Badge tone="gold">BORRADOR SIMULADO</Badge><span>FUENTE · {generated.source}</span></header><h2>INFORME CREADO POR EL AGENTE</h2><p>{generated.summary}</p><div>{generated.topics.map(topic=><span key={topic}>{topic}</span>)}</div><footer><strong>{generated.questions} PREGUNTAS</strong><strong>{generated.tasks} TAREAS PROPUESTAS</strong><button onClick={()=>inspect({name:generated.source,subject:"Por clasificar",owner:"Agente docente",size:"—",status:"Borrador IA",questions:generated.questions})}>REVISAR RESULTADO</button></footer></section>}<Panel tag={`${materials.length} ARCHIVOS`} title="MATERIALES RECIENTES"><div className={styles.files}>{materials.map((m,i)=><div key={`${m.name}${i}`}><span>{m.name.split(".").pop()?.toUpperCase()}</span><strong>{m.name}<small>{m.subject} · {m.owner} · {m.size}</small></strong><Badge tone={m.status==="Listo"?"green":"gold"}>{m.status}</Badge><i>{m.questions} PREGUNTAS</i><button onClick={()=>inspect(m)}>ABRIR</button></div>)}</div></Panel></>}

function Questions({questions,approve}:{questions:Question[];approve:(id:number)=>void}){const pending=questions.filter(q=>!q.approved).length;return <><Header overline="CONTROL PEDAGÓGICO" title="BANCO DE PREGUNTAS" text="Meta de 100 por materia. Solo las aprobadas pueden poblar nodos del grafo." action={<button className={styles.primary}>GENERAR BORRADOR</button>}/><div className={styles.questionStats}><div><strong>384</strong><span>TOTALES</span></div><div><strong>368</strong><span>APROBADAS</span></div><div><strong>{pending}</strong><span>EN ESTA COLA</span></div><div><strong>05</strong><span>POR NODO</span></div></div><div className={styles.questionSplit}><Panel tag="COLA DOCENTE" title="PREGUNTAS POR REVISAR"><div className={styles.questions}>{questions.map((q,i)=><div key={q.id}><span>Q-{String(i+1).padStart(3,"0")}</span><section><Badge tone={q.subject==="Matemática"?"red":"violet"}>{q.subject}</Badge><strong>{q.text}</strong><small>A) Alternativa · B) Correcta · C) Distractor · D) Distractor</small></section>{q.approved?<Badge tone="green">APROBADA</Badge>:<button onClick={()=>approve(q.id)}>REVISAR Y APROBAR</button>}</div>)}</div></Panel><Panel tag="PROTOCOLO" title="USO INTELIGENTE"><ol className={styles.rules}><li>La IA crea borradores desde material validado.</li><li>El profesor corrige alternativas y explicación.</li><li>Cada nodo usa cinco preguntas sin repetición inmediata.</li><li>El banco reduce regeneraciones y consumo de tokens.</li></ol></Panel></div></>}

function Tasks({student}:{student:boolean}){return <><Header overline={student?"MISIONES ACTIVAS":"GESTIÓN DE APRENDIZAJE"} title="TAREAS" text={student?"Completa encargos y gana XP.":"Alternativas, respuesta escrita o entrega de documentos por sección."} action={!student?<button className={styles.primary}>CREAR TAREA</button>:undefined}/><div className={styles.taskGrid}>{[["HOY","Fracciones equivalentes","Matemática","Alternativas","80 XP"],["04 AGO","Informe del sistema solar","Ciencia","Documento","120 XP"],["08 AGO","Crónica de mi comunidad","Comunicación","Respuesta escrita","100 XP"]].map((x,i)=><article key={x[1]}><header><span>{x[0]}</span><Badge tone={i===0?"red":"plain"}>{i===0?"URGENTE":"PROGRAMADA"}</Badge></header><small>{x[2]}</small><h2>{x[1]}</h2><p>6.º Primaria A · {x[3]}</p><footer><strong>{x[4]}</strong><span>{student?"ABRIR MISIÓN":i===0?"24 / 28 ENTREGAS":"BORRADOR"}</span></footer></article>)}</div></>}

function Battles(){return <><Header overline="ARENA ESTRATÉGICA" title="BATALLAS Y TORNEOS" text="Enfrentamientos por turnos, rutas conectadas y captura por mejor tiempo." action={<Link className={styles.primary} href="/#inicio">ABRIR DEMO DE BATALLA</Link>}/><div className={styles.battle}><section><Badge tone="red">EN VIVO · RONDA 4</Badge><h2>6.º A <span>VS</span> 6.º B</h2><p>Batalla entre secciones · 18 de 28 activos</p><div><strong>ROJO 07</strong><i/><strong>MORADO 05</strong></div></section><div className={styles.miniMap}><Castle/><i/><b>MAT</b><i/><b>CIE</b><i/><b>COM</b><i/><Castle violet/></div></div><div className={styles.battleCards}>{[["PRÓXIMA","Camila vs Joaquín","HOY · 15:30"],["PROGRAMADA","5.º A vs 5.º B","05 AGO · 10:00"],["FINALIZADA","Diego vs Mateo","ROJO GANÓ"]].map(x=><Panel key={x[1]} tag={x[0]} title={x[1]}><p>{x[2]}</p><button>VER DETALLE</button></Panel>)}</div></>}

function Progress({student}:{student:boolean}){return <><Header overline="SISTEMA DE PROGRESO" title="RANGOS, CLANES Y XP" text={student?"Tu progreso combina batallas y tareas.":"Define rangos institucionales y organiza clanes por sección."} action={!student?<button className={styles.primary}>CONFIGURAR RANGOS</button>:undefined}/><div className={styles.ranks}>{[["R1","APRENDIZ","0 XP"],["R2","EXPLORADOR","500 XP"],["R3","ESTRATEGA","1,200 XP"],["R4","COMANDANTE","2,500 XP"],["R5","MAESTRO","5,000 XP"]].map((x,i)=><div className={i===2?styles.current:""} key={x[0]}><span>{x[0]}</span><strong>{x[1]}</strong><small>{x[2]}</small></div>)}</div><div className={styles.split}><Panel tag="6.º A" title="CLASIFICACIÓN DE CLANES"><ol className={styles.clans}><li>01 <strong>Los Amautas</strong><b>8,420 XP</b></li><li>02 <strong>Los Quipus</strong><b>7,980 XP</b></li><li>03 <strong>Guardianes del Sol</strong><b>7,210 XP</b></li></ol></Panel><Panel tag="SEMANA ACTUAL" title="FUENTES DE XP"><div className={styles.xp}><strong>12,840</strong><span>XP ACUMULADA</span></div></Panel></div></>}

function Audit(){return <><Header overline="TRAZABILIDAD" title="ACTIVIDAD Y AUDITORÍA" text="Cambios sensibles, publicaciones, accesos y moderación." action={<button className={styles.primary}>EXPORTAR REGISTRO</button>}/><Panel tag="HOY" title="REGISTRO INSTITUCIONAL"><div className={styles.audit}>{[["14:32","Ana Torres","Aprobó 12 preguntas","Banco de Ciencia"],["14:08","Lucía Vargas","Publicó una tarea","6.º A"],["13:45","Dirección","Actualizó permisos","Diego Ramos"],["12:20","Sistema","Finalizó una batalla","6.º A vs 6.º B"]].map(x=><div key={x[0]}><span>{x[0]}</span><i/><strong>{x[1]}</strong><p>{x[2]}</p><Badge>{x[3]}</Badge><button>DETALLE</button></div>)}</div></Panel></>}

function DemoModal({modal,close,complete}:{modal:ModalState;close:()=>void;complete:(event:FormEvent<HTMLFormElement>)=>void}){
  const fields:Record<ModalKind,React.ReactNode>={
    school:<><label>Nombre institucional<input defaultValue="I.E. Horizonte"/></label><label>Turno principal<select><option>Mañana</option><option>Tarde</option></select></label></>,
    subject:<><label>Nombre de la materia<input defaultValue="Geografía y ciudadanía"/></label><label>Color del nodo<select><option>Morado imperial</option><option>Rojo carmesí</option><option>Dorado</option></select></label><label>Docente responsable<select><option>Ana Torres</option><option>Diego Ramos</option><option>Sin asignar</option></select></label></>,
    user:<><label>Nombres y apellidos<input defaultValue="Valeria Castillo"/></label><label>Rol<select><option>Profesor</option><option>Tutor</option><option>Alumno</option><option>Subdirector</option></select></label><label>Sección o alcance<select><option>6.º Primaria A</option><option>6.º Primaria B</option><option>Todo el colegio</option></select></label></>,
    import:<><label>Archivo de nómina<input type="file" accept=".csv,.xlsx"/></label><p>La simulación detectará nombres, correos y sección sin guardar datos reales.</p></>,
    task:<><label>Título de la tarea<input defaultValue="Misión: guardianes del agua"/></label><label>Tipo<select><option>Alternativas</option><option>Respuesta escrita</option><option>Entrega de documento</option></select></label><label>Recompensa XP<input type="number" defaultValue="100"/></label></>,
    rank:<><label>Nombre del rango<input defaultValue="Guardián del saber"/></label><label>XP requerido<input type="number" defaultValue="3500"/></label></>,
    detail:<><div className={styles.modalSummary}><Badge tone="green">REGISTRO DISPONIBLE</Badge><p>Esta vista usa datos ficticios coherentes con el prototipo. En producción mostrará la información persistida por el backend del colegio.</p><dl><div><dt>ESTADO</dt><dd>Listo para revisión</dd></div><div><dt>ALCANCE</dt><dd>I.E. Horizonte</dd></div><div><dt>RESPONSABLE</dt><dd>Dirección académica</dd></div></dl></div></>,
    export:<><label>Formato<select><option>PDF institucional</option><option>CSV de actividad</option></select></label><label>Periodo<select><option>Últimos 30 días</option><option>Semestre actual</option></select></label></>,
  };
  return <div className={styles.modalBackdrop} onMouseDown={event=>{if(event.target===event.currentTarget)close()}}><section className={styles.modal} role="dialog" aria-modal="true" aria-labelledby="modal-title"><button autoFocus className={styles.modalClose} onClick={close} aria-label="Cerrar modal">CERRAR</button><span>VENTANA DE GESTIÓN</span><h2 id="modal-title">{modal.title}</h2><p>{modal.subtitle}</p><form onSubmit={complete}>{fields[modal.kind]}<footer><button type="button" onClick={close}>CANCELAR</button><button className={styles.primary} type="submit">GUARDAR DEMO</button></footer></form></section></div>;
}
