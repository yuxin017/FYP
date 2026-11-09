package my.edu.tarumt.collaborative_asg

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.nfc.tech.IsoDep
import android.nfc.tech.Ndef
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var speechResult:MethodChannel.Result?=null
    private var readResult:MethodChannel.Result?=null
    private var previousBrightness:Float?=null
    private val handler=Handler(Looper.getMainLooper())
    private val readTimeout=Runnable { finishRead(null,"No pass was detected. Try again or scan the QR code.") }
    override fun configureFlutterEngine(engine:FlutterEngine){
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger,"themepark/screen").setMethodCallHandler { call,result ->
            if(call.method!="brightness"){result.notImplemented();return@setMethodCallHandler}
            val enabled=call.argument<Boolean>("enabled")==true
            val attributes=window.attributes
            if(enabled){if(previousBrightness==null)previousBrightness=attributes.screenBrightness;attributes.screenBrightness=1.0f}
            else{attributes.screenBrightness=previousBrightness?:-1.0f;previousBrightness=null}
            window.attributes=attributes;result.success(true)
        }
        MethodChannel(engine.dartExecutor.binaryMessenger,"themepark/speech").setMethodCallHandler { call,result ->
            if(call.method!="listen"){result.notImplemented();return@setMethodCallHandler}
            if(speechResult!=null){result.error("busy","Voice input is already listening.",null);return@setMethodCallHandler}
            speechResult=result
            try{startActivityForResult(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply{putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);putExtra(RecognizerIntent.EXTRA_LANGUAGE,call.argument<String>("language")?:"en-GB");putExtra(RecognizerIntent.EXTRA_PROMPT,"Ask the Park Assistant")},8401)}
            catch(e:Exception){speechResult=null;result.error("unavailable","Voice input is unavailable on this device. Please type your question.",null)}
        }
        MethodChannel(engine.dartExecutor.binaryMessenger,"themepark/nfc-pass").setMethodCallHandler { call,result ->
            val adapter=NfcAdapter.getDefaultAdapter(this)
            when(call.method){
                "preparePass" -> {
                    val value=call.argument<String>("payload")?:""
                    if(adapter==null || !packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)){result.error("unsupported","NFC pass sharing is unavailable.",null)}
                    else if(!adapter.isEnabled){result.error("disabled","Turn on NFC in your device settings.",null)}
                    else if(!validPass(value)){result.error("invalid","Choose a valid park pass.",null)}
                    else{ParkPassService.payload=NdefMessage(arrayOf(NdefRecord.createTextRecord("en",value))).toByteArray();ParkPassService.expiresAt=SystemClock.elapsedRealtime()+60000;CardEmulation.getInstance(adapter).setPreferredService(this,ComponentName(this,ParkPassService::class.java));result.success(true)}
                }
                "stopPass" -> {ParkPassService.clear();if(adapter!=null)CardEmulation.getInstance(adapter).unsetPreferredService(this);result.success(null)}
                "readPass" -> {
                    if(adapter==null){result.error("unsupported","This device has no NFC reader.",null)}
                    else if(!adapter.isEnabled){result.error("disabled","Turn on NFC in your device settings.",null)}
                    else if(readResult!=null){result.error("busy","The reader is already waiting for a pass.",null)}
                    else{ParkPassService.clear();readResult=result;adapter.enableReaderMode(this,{ tag ->
                        try{
                            val ndef=Ndef.get(tag)
                            val message=if(ndef!=null){ndef.connect();try{ndef.ndefMessage}finally{ndef.close()}}else{
                                val iso=IsoDep.get(tag)?:throw IllegalArgumentException();iso.connect();iso.timeout=5000
                                try{
                                    fun exchange(command:ByteArray):ByteArray{val data=iso.transceive(command);if(data.size<2||data[data.size-2]!=0x90.toByte()||data.last()!=0.toByte())throw IllegalArgumentException();return data.copyOfRange(0,data.size-2)}
                                    exchange(byteArrayOf(0,0xA4.toByte(),4,0,7,0xD2.toByte(),0x76,0,0,0x85.toByte(),1,1,0));exchange(byteArrayOf(0,0xA4.toByte(),0,0x0C,2,0xE1.toByte(),4));val length=exchange(byteArrayOf(0,0xB0.toByte(),0,0,2));val size=((length[0].toInt()and 255)shl 8)or(length[1].toInt()and 255);if(size>1500)throw IllegalArgumentException();val bytes=ArrayList<Byte>();var offset=2;while(bytes.size<size){val count=minOf(200,size-bytes.size);bytes.addAll(exchange(byteArrayOf(0,0xB0.toByte(),(offset shr 8).toByte(),offset.toByte(),count.toByte())).toList());offset=bytes.size+2};NdefMessage(bytes.toByteArray())
                                }finally{iso.close()}
                            }
                            val record=message.records.firstOrNull{it.tnf==NdefRecord.TNF_WELL_KNOWN&&it.type.contentEquals(NdefRecord.RTD_TEXT)}?:throw IllegalArgumentException();val bytes=record.payload;val skip=1+(bytes[0].toInt()and 63);val value=String(bytes.copyOfRange(skip,bytes.size),Charsets.UTF_8);if(!validPass(value))throw IllegalArgumentException();runOnUiThread{finishRead(value,null)}
                        }catch(e:Exception){runOnUiThread{finishRead(null,"This tag does not contain a valid park pass. Please scan the QR code.")}}
                    },NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B,null);handler.postDelayed(readTimeout,30000)}
                }
                "stopReader" -> {finishRead(null,"NFC reading was cancelled.");result.success(null)}
                else -> result.notImplemented()
            }
        }
    }
    private fun validPass(value:String)=value.length<=300 && Regex("^(TP1|RQ1|PK1|RV1):[A-Za-z0-9_:-]+$").matches(value)
    private fun finishRead(value:String?,error:String?){handler.removeCallbacks(readTimeout);NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this);val result=readResult;readResult=null;if(value!=null)result?.success(value)else result?.error("unavailable",error,null)}
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?){super.onActivityResult(requestCode,resultCode,data);if(requestCode==8401){val result=speechResult;speechResult=null;if(resultCode==Activity.RESULT_OK)result?.success(data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?:"")else result?.success("")}}
    override fun onDestroy(){ParkPassService.clear();finishRead(null,"Reader closed.");speechResult?.success("");speechResult=null;super.onDestroy()}
}
