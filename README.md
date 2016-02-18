# Image Cropper
ImageCropper JS Plugin, pure Javascript with FileReader/Canvas/Blob APIs

**It is used in Teambition Web project cover & user avatar crop**

## Usage

```
# params
{
  input # file input selector or input element for choosing file
  container # source image container selector or dom element
  containerWidth # container width 
  containerHeight # optional, default is 240, adjust with @param ratio
  widthAdapt # optional, for image width adapt to container width
  heightAdapt # optional, for image height adapt to container height
  cropperWidth # optional, default is 0.8 container width/height
  ratio # optional, cropper ratio, default is 1
  resultWidth # optional, default is cropperWidth
  round # optional, enable central round selector, defalut is false
  crop # optional, cropped callback, revoked every cropped area changed
  file # optional, the file resource
}

```
**Notice: ** `cropperListener(hd = true)` the `hd` param for performance consideration, default is `false` in cropper movement, cropper resizer movement and souce image movement `cropperListener` calls. That means when stopping moving, the cropped src changed from low definition(cropper size) to high definition (origin definition).

If for hd, remove the `fasle` param in those calls.





## Demo

```
# used in teambition web project cover crop
imageCropper = new ImageCropper({
  input: @$('.image-cropper-input')[0]
  container: @$('.image-cropper-wrapper')[0]
  containerWidth: 600
  resultWidth: 600
  ratio: 3 / 1
  file: @file # the file
  fileSizeLimit: 4 * 1024 * 1024
  crop: (data) ->
    # data is the cropped canvas src
    # do something
    ### eg:
    previewL.getContext('2d').drawImage(data, 0, 0, previewL.width,
      previewL.height)
    previewM.getContext('2d').drawImage(data, 0, 0, previewM.width,
      previewM.height)
    previewS.getContext('2d').drawImage(data, 0, 0, previewS.width,
      previewS.height)
    ###
  onError: (type) ->
    # type is errorType, now is 'sizeTooLarge'
    # do something
 })
```

```
# used in teambition web user avatar crop
imageCropper = new ImageCropper({
  input: $('.image-cropper-input')[0]
  container: $('.image-cropper-wrapper')[0]
  containerWidth: 320
  containerHeight: 320
  widthAdapt: true
  cropperWidth: 200
  ratio: 1
  round: true
  file: @file
  crop: (data) ->
    # data is the cropped canvas src
    # do something
})
```

## APIs
* **toBlob()** convert the cropped canvas src to a Blob, `image/png`
* **toDataURL()** DataUrl data, base64 
* **destroy()** remove all relevant listeners
