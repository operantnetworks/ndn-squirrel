/**
 * Copyright (C) 2016 Regents of the University of California.
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
 * A DynamicBlobArray holds a Squirrel blob and provides methods to ensure a
 * minimum capacity, resizing if necessary.
 */
class DynamicBlobArray {
  array_ = null;

  /**
   * Create a new DynamicBlobArray with an initial size.
   * @param initialSize The initial size of the allocated array.
   */
  constructor(initialSize)
  {
    array_ = blob(initialSize);
  }

  /**
   * Ensure that the array has the minimal size, resizing it if necessary.
   * The new size of the array may be greater than the given size. 
   * @param {integer} length The minimum length for the array.
   */
  function ensureSize(size)
  {
    // array_.len() is always the full size of the array.
    if (array_.len() >= size)
      return;

    // See if double is enough.
    local newSize = array_.len() * 2;
    if (size > newSize)
      // The needed size is much greater, so use it.
      newSize = size;

    // Instead of using resize, we manually copy to a new blob so that
    // array_.len() will be the full size.
    local newArray = blob(newSize);
    newArray.writeblob(array_);
    array_ = newArray;
  }

  /**
   * Copy the given array into this object's array, using ensureSize to make
   * sure there is enough room.
   * @param {blob} array A Squirrel blob with the array of bytes to copy. This
   * ignores the array read/write pointer.
   * @param {integer} arrayOffset The index in array of the first byte to copy.
   * @param {integer} arrayLength The number of bytes to copy.
   * @param {offset} The offset in this object's array to copy to.
   */
  function copy(array, arrayOffset, arrayLength, offset)
  {
    ensureSize(offset + arrayLength);

    array_.seek(offset);
    if (arrayOffset == 0 && arrayLength == array.len())
      // The simple case to avoid using readblob.
      array_.writeblob(array);
    else {
      // TODO: readblob makes a copy. Can we avoid that?
      // Set and restore the read/write pointer.
      local savePointer = array.tell();
      array.seek(arrayOffset);
      array_.writeblob(array.readblob(arrayLength));

      array.seek(savePointer);
    }
  }

  /**
   * Resize this object's array to the given size, transfer the bytes to a Blob
   * and return the Blob. Finally, set this object's array to null to prevent
   * further use.
   * @param {integer} size The final size of the allocated array.
   * @return {Blob} A new NDN Blob with the bytes from the array.
   */
  function finish(size)
  {
    array_.resize(size);
    local result = Blob(array_, false);
    array_ = null;
    return result;
  }
}
