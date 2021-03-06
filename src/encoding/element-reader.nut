/**
 * Copyright (C) 2016-2018 Regents of the University of California.
 * @author: Jeff Thompson <jefft0@remap.ucla.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * A copy of the GNU Lesser General Public License is in the file COPYING.
 */

/**
 * An ElementReader lets you call onReceivedData multiple times which uses a
 * TlvStructureDecoder to detect the end of a TLV element and calls
 * elementListener.onReceivedElement(element) with the element. If the packet 
 * contains a packet extensions header, it is included in the element (even 
 * though it is not TLV); you can use PacketExtensions.getNHeaderBytes to skip
 * it. This handles the case where a single call to onReceivedData may contain
 * multiple elements.
 */
class ElementReader {
  elementListener_ = null;
  dataParts_ = null;
  tlvStructureDecoder_ = null;

  /**
   * Create a new ElementReader with the elementListener.
   * @param {instance} elementListener An object with an onReceivedElement
   * method.
   */
  constructor(elementListener)
  {
    elementListener_ = elementListener;
    dataParts_ = [];
  }

  /**
   * Continue to read data until the end of an element, then call
   * elementListener_.onReceivedElement(element). The Buffer passed to
   * onReceivedElement is only valid during this call.  If you need the data
   * later, you must copy.
   * @param {Buffer} data The Buffer with the incoming element's bytes.
   */
  function onReceivedData(data)
  {
    // Process multiple elements in the data.
    while (true) {
      local gotElementEnd;
      local offset;

      try {
        local startOffset = 0;
        if (tlvStructureDecoder_ == null) {
          // We haven't started reading the beginning of an element yet.
          if (data.len() <= 0)
            // Wait for more data.
            return;

          // As a special case, skip the packet extensions header which does not
          // use TLV.
          startOffset = PacketExtensions.getNHeaderBytes(data);
          if (startOffset > 0 && startOffset >= data.len()) {
            // The buffer only had extensions. Save a copy to concat later.
            dataParts_.push(Buffer(data));
            return;
          }
        }

        // Scan the input to check if a whole TLV element has been read.
        if (tlvStructureDecoder_ == null)
          tlvStructureDecoder_ = TlvStructureDecoder();
        tlvStructureDecoder_.seek(startOffset);
        gotElementEnd = tlvStructureDecoder_.findElementEnd(data);
        offset = tlvStructureDecoder_.getOffset();
      } catch (ex) {
        // Reset to read a new element on the next call.
        dataParts_ = [];
        tlvStructureDecoder_ = null;

        throw ex;
      }

      if (gotElementEnd) {
        // Got the remainder of an element.  Report to the caller.
        // Note: The element buffer includes any packet extensions header.
        local element;
        if (dataParts_.len() == 0)
          element = data.slice(0, offset);
        else {
          dataParts_.push(data.slice(0, offset));
          element = Buffer.concat(dataParts_);
          dataParts_ = [];
        }

        // Reset to read a new element. Do this before calling onReceivedElement
        // in case it throws an exception.
        data = data.slice(offset, data.len());
        tlvStructureDecoder_ = null;

        elementListener_.onReceivedElement(element);
        if (data.len() == 0)
          // No more data in the packet.
          return;

        // else loop back to decode.
      }
      else {
        // Save a copy. We will call concat later.
        local totalLength = data.len();
        for (local i = 0; i < dataParts_.len(); ++i)
          totalLength += dataParts_[i].len();
        if (totalLength > NdnCommon.MAX_NDN_PACKET_SIZE) {
          // Reset to read a new element on the next call.
          dataParts_ = [];
          tlvStructureDecoder_ = null;

          throw "The incoming packet exceeds the maximum limit Face.getMaxNdnPacketSize()";
        }

        dataParts_.push(Buffer(data));
        return;
      }
    }
  }
}
