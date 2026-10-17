///|
extern "js" fn lesson_practice_csv_bridge(
  session : String,
  input : String,
  template : Bool,
) -> String =
  #| (session,input,template)=>{
  #|   try {
  #|     const s=JSON.parse(session), columns=['round','practice','record_id','record_version','record_digest','exercise','before','after','feedback','next_practice'];
  #|     const quote=v=>'"'+String(v).replaceAll('"','""')+'"';
  #|     const identity=(item,i)=>[String(s.previous_rounds.length+1),String(i+1),item.snapshot.reference.record_id,item.snapshot.reference.record_version,item.snapshot.reference.record_digest,item.exercise];
  #|     if(template)return [columns.join(','),...s.teaching.items.map((item,i)=>[...identity(item,i),'','','',''].map(quote).join(','))].join('\r\n')+'\r\n';
  #|     if(new TextEncoder().encode(input).length>1048576)throw Error('Use at most 1 MiB of CSV.');
  #|     const rows=[];let row=[],field='',mode='start';
  #|     if(input.charCodeAt(0)===0xfeff)input=input.slice(1);
  #|     for(let i=0;i<input.length;i++){
  #|       const c=input[i];
  #|       if(mode==='quoted'){if(c==='"'){if(input[i+1]==='"'){field+='"';i++;}else mode='closed';}else field+=c;continue;}
  #|       if(c===','||c==='\n'||c==='\r'){
  #|         row.push(field);field='';mode='start';
  #|         if(c!==','){if(c==='\r'&&input[i+1]==='\n')i++;rows.push(row);row=[];}continue;
  #|       }
  #|       if(mode==='closed')throw Error('Unexpected text after a closing CSV quote.');
  #|       if(c==='"'){if(mode!=='start')throw Error('Quote the complete CSV field.');mode='quoted';}
  #|       else {field+=c;mode='plain';}
  #|     }
  #|     if(mode==='quoted')throw Error('Unclosed CSV quote.');
  #|     if(row.length||field!==''||mode!=='start'){row.push(field);rows.push(row);}
  #|     if(JSON.stringify(rows.shift())!==JSON.stringify(columns))throw Error('Use the exact response-template header.');
  #|     if(!rows.length||rows.length>s.teaching.items.length)throw Error('Include one or more current practice rows, each at most once.');
  #|     const seen=new Set();
  #|     for(const r of rows){
  #|       if(r.length!==columns.length)throw Error('Every CSV row needs all ten columns.');
  #|       const i=Number(r[1])-1;
  #|       if(!Number.isInteger(i)||i<0||i>=s.teaching.items.length||seen.has(i))throw Error('Unknown or duplicate practice row.');
  #|       if(JSON.stringify(r.slice(0,6))!==JSON.stringify(identity(s.teaching.items[i],i)))throw Error('Round, task or exact lesson identity changed; use the current template.');
  #|       seen.add(i);
  #|       for(let j=6;j<10;j++){
  #|         const key=columns[j], value=r[j],old=s.observations[i][key];
  #|         if(value.length>16384)throw Error('Observation fields support at most 16384 characters.');
  #|         if(value==='')continue;
  #|         if(old!==''&&old!==value)throw Error('An existing response differs. Edit it explicitly in the workbook; CSV does not overwrite it.');
  #|         s.observations[i][key]=value;
  #|       }
  #|     }
  #|     return JSON.stringify({workbook:s});
  #|   }catch(e){return JSON.stringify({error:e.message});}
  #| }

///|
fn lesson_practice_csv_preview(
  session : LessonPracticeSession,
  input : String,
) -> Result[LessonPracticeSession, String] {
  let result = @json.parse(
    lesson_practice_csv_bridge(
      ToJson::to_json(session).stringify(),
      input,
      false,
    ),
  ) catch {
    _ => return Err("Could not read the CSV preview.")
  }
  match result {
    { "error": String(error), .. } => Err(error)
    { "workbook": workbook, .. } => lesson_practice_decode(workbook.stringify())
    _ => Err("No practice workbook was produced.")
  }
}
