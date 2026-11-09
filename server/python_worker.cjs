'use strict';
const {spawn}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
class PythonWorker{
  constructor({root=path.resolve(__dirname,'..')}={}){this.root=root;this.pending=new Map();this.sequence=0;this.process=null;}
  start(){
    if(this.process)return;
    const configured=path.join(this.root,'.local/python.path');
    let runtime={};try{runtime=JSON.parse(fs.readFileSync(path.join(this.root,'.local/runtime.json'),'utf8'));}catch(_){}
    const python=process.env.FYP_PYTHON||runtime.python||(fs.existsSync(configured)?fs.readFileSync(configured,'utf8').trim():'');
    if(!path.isAbsolute(python)||!fs.existsSync(python))throw Error('AI services need Python setup. Run tool/setup.cmd.');
    const child=spawn(python,['-u',path.join(this.root,'ai/worker.py')],{cwd:this.root,windowsHide:true,stdio:['pipe','pipe','pipe']});
    this.process=child;let buffer='';
    const failed=()=>{if(this.process===child)this.process=null;for(const job of this.pending.values()){clearTimeout(job.timer);job.reject(Error('The AI service stopped. Please retry or run the AI setup command.'));}this.pending.clear();};
    child.on('error',failed);child.on('exit',failed);child.stderr.on('data',()=>{});
    child.stdout.setEncoding('utf8');child.stdout.on('data',chunk=>{
      buffer+=chunk;if(buffer.length>20_000_000){child.kill();return;}
      let end;while((end=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,end);buffer=buffer.slice(end+1);let answer;try{answer=JSON.parse(line);}catch(_){child.kill();return;}
        const job=this.pending.get(answer.id);if(!job)continue;this.pending.delete(answer.id);clearTimeout(job.timer);if(answer.error)job.reject(Error(answer.error));else job.resolve(answer.result);
      }
    });
  }
  async call(operation,data={}){
    if(this.pending.size>=4)throw Error('Photo processing is busy. Please try again shortly.');this.start();const id=++this.sequence;
    return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{this.pending.delete(id);reject(Error('Photo processing took too long. Please try again.'));},90000);timer.unref();this.pending.set(id,{resolve,reject,timer});this.process.stdin.write(JSON.stringify({...data,id,operation})+'\n',error=>{if(error){clearTimeout(timer);this.pending.delete(id);reject(Error('Unable to reach the AI service. Please retry.'));}});});
  }
  close(){const child=this.process;this.process=null;child?.stdin.end();}
}
module.exports={PythonWorker};
