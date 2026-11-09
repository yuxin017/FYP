package my.edu.tarumt.collaborative_asg

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.SystemClock

class ParkPassService : HostApduService() {
    private val protocol=NdefApdu()
    override fun processCommandApdu(commandApdu:ByteArray?,extras:Bundle?):ByteArray =
        protocol.process(commandApdu,if(SystemClock.elapsedRealtime()<expiresAt)payload else null)
    override fun onDeactivated(reason:Int){protocol.reset()}
    companion object {
        @Volatile var payload:ByteArray?=null
        @Volatile var expiresAt:Long=0
        fun clear(){payload=null;expiresAt=0}
    }
}
