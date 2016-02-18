# ImageCropper JS Plugin, pure Javascript with FileReader/Canvas/Blob APIs
class ImageCropper
  constructor: (options) ->
    @inputId = options.input # file input selector
    @containerId = options.container # source image container selector
    @containerWidth = options.containerWidth
    @containerHeight = options.containerHeight or 240
    @widthAdapt = options.widthAdapt or false
    @heightAdapt = options.heightAdapt or false
    @cropperWidth = options.cropperWidth or 0
    @cropperRatio = options.ratio or 1 # cropper ratio
    @croppedWidth = options.resultWidth or @cropperWidth
    @cropperRound = options.round or false # enable central round selector
    @cropCallback = options.crop or null
    @onError = options.onError or null
    @fileSizeLimit = options.fileSizeLimit or Infinity

    # initialize selector binding
    @input = options.input or document.querySelector(@inputId) # input, file type, accept image
    @container = options.container or document.querySelector(@containerId) # container for whole plugin
    @imageContainer = document.createElement('div') # image container
    @imageContainer.style.position = 'relative'
    @imageContainer.style.top = '0px'
    @imageContainer.style.left = '0px'
    @imageContainer.style.overflow = 'hidden'
    @imageContainer.style.width = "#{@containerWidth}px"
    @imageContainer.style.height = "#{@containerHeight}px"
    @_events = {}

    # components options
    @sourceImage = document.createElement('canvas') # source image
    @cropper = document.createElement('canvas') # cropper selector
    @cropperSeResize = document.createElement('canvas') # cropperSeResize
    @cropperSource = document.createElement('canvas') # clean cropper source
    @image = new Image() # add image file source to memeory
    @imageRatio = 1 # source image & scaled image ratio
    @reader = new FileReader()

    # se-resize cursor attrs
    @cropperSeResizeSize = 10

    # offsets for locatation
    @cropperOffsetTop = 0
    @cropperOffsetLeft = 0
    @imageOffsetTop = 0 # image position
    @imageOffsetLeft = 0

    # global componennts mousemove attrs
    @cropperPrevX = 0 # cropper's
    @cropperPrevY = 0
    @imagePrevX = 0 # source image
    @imagePrevY = 0
    @cropperResizePrevX = 0 # cropper-se-resize's
    @cropperResizePrevY = 0

    # events bind here
    @listenTo(@input, 'change', @readFile)
    @listenTo(@reader, 'load', @fileReady)
    @listenTo(@image, 'load', @imageReady)
    @listenTo(@sourceImage, 'mousedown', @sourceImageMousedown)
    @listenTo(@sourceImage, 'touchstart', @sourceImageMousedown)
    @listenTo(@cropper, 'mousedown', @cropperMousedown)
    @listenTo(@cropper, 'touchstart', @cropperMousedown)
    @listenTo(@cropperSeResize, 'mousedown', @cropperSeResizeMousedown)
    @listenTo(@cropperSeResize, 'touchstart', @cropperSeResizeMousedown)
    @listenTo(document, 'mouseup', @stopListeningMousemove)
    @listenTo(document, 'touchend', @stopListeningMousemove)

    @container.innerHTML = ''
    @container.appendChild(@imageContainer)

    if options.file
      if options.file.size > @fileSizeLimit
        @onError?('sizeTooLarge')
        return
      @reader.readAsDataURL(options.file)

  stopListeningMousemove: ->
    @stopListening(document, 'mousemove')
    @stopListening(document, 'touchmove')
    @cropperListener()

  # events bind handler
  listenTo: (ele, eventName, eventListener) ->
    @_events[eventName] or= []
    eventListener = eventListener.bind(@)
    @_events[eventName].push({
      ele: ele
      eventListener: eventListener
    })
    ele.addEventListener(eventName, eventListener, false)

  # events unbind handler
  stopListening: (ele, eventName) ->
    unless ele
      for eventName, events of @_events
        for item in events
          item.ele.removeEventListener(eventName, item.eventListener, false)
      @_events = {}
    else
      data = @_events[eventName] or []
      @_events[eventName] = []
      for item in data
        if item.ele is ele
          ele.removeEventListener(eventName, item.eventListener, false)
        else
          @_events[eventName].push(item)

  # read image file
  readFile: (e) ->
    file = e.target.files[0]
    if file
      if file.size > @fileSizeLimit
        @onError?('sizeTooLarge')
        return
      @reader.readAsDataURL(e.target.files[0])

  # read image file and initialize cropper components
  fileReady: (e) ->
    @image.src = e.target.result

  # source image style initialize
  imageReady: ->
    @sourceImage.width = @image.width
    @sourceImage.height = @image.height
    sourceImageCtx = @sourceImage.getContext('2d')
    sourceImageCtx.fillStyle = 'white' # white background, considering transparent
    sourceImageCtx.fillRect(0, 0, @image.width, @image.height) # white background
    sourceImageCtx.drawImage(@image, 0, 0) # draw source image
    sourceImageCtx.fillStyle = 'rgba(0, 0, 0, 0.5)' # mask effect
    sourceImageCtx.fillRect(0, 0, @image.width, @image.height)
    @sourceImage.style.cursor = 'move'
    @sourceImage.style.position = 'relative'
    @sourceImage.style.top = '0px'
    @sourceImage.style.left = '0px'
    @imageContainer.appendChild(@sourceImage)

    # source image width/height adjust
    widthAdapt = =>
      @sourceImage.style.width = "#{@containerWidth}px"
      @sourceImageWidth = @containerWidth
      sourceImageHeight = @image.height * @containerWidth / @image.width
      @sourceImage.style.height = "#{sourceImageHeight}px"
      @sourceImageLeft = 0
      @sourceImageTop = (@containerHeight - sourceImageHeight) / 2
      @sourceImage.style.top = "#{@sourceImageTop}px"

    heightAdapt = =>
      @sourceImage.style.height = "#{@containerHeight}px"
      @sourceImageWidth = @image.width * @containerHeight / @image.height
      @sourceImage.style.width = "#{@sourceImageWidth}px"
      @sourceImageLeft = (@containerWidth - @sourceImageWidth) / 2
      @sourceImageTop = 0
      @sourceImage.style.left = "#{@sourceImageLeft}px"

    if @widthAdapt and not @heightAdapt
      widthAdapt()
    else if @heightAdapt and not @widthAdapt
      heightAdapt()
    else
      if @image.width / @image.height >= @containerWidth / @containerHeight
        heightAdapt()
      else
        widthAdapt()

    @imageStyleWidth = parseInt(@sourceImage.style.width.slice(0, -2))
    @imageStyleHeight = parseInt(@sourceImage.style.height.slice(0, -2))
    cropperBaseWidth = @imageStyleWidth
    cropperBaseWidth = @containerWidth if @imageStyleWidth > @containerWidth
    cropperBaseHeight = @imageStyleHeight
    cropperBaseHeight = @containerHeight if @imageStyleHeight > @containerHeight

    # source image real size & show size ratio & real image offsets
    @imageRatio = @sourceImageWidth / @sourceImage.width
    @imageOffsetTop = @sourceImageTop / @imageRatio
    @imageOffsetLeft = @sourceImageLeft / @imageRatio

    # cropper size revision
    @cropperWidth = @containerWidth * 0.8 if @cropperWidth is 0
    @cropperHeight = @cropperWidth / @cropperRatio
    if @cropperRatio > cropperBaseWidth / cropperBaseHeight
      if @cropperWidth > cropperBaseWidth
        @cropperWidth = @cropperBaseWidth * 0.8
        @cropperHeight = @cropperWidth / @cropperRatio
    else
      if @cropperHeight > cropperBaseHeight
        @cropperHeight = cropperBaseHeight * 0.8
        @cropperWidth = @cropperHeight * @cropperRatio

    # cropper initialize
    @cropperOffsetTop = (@containerHeight - @cropperHeight) / 2
    @cropperOffsetLeft = (@containerWidth - @cropperWidth) / 2
    @cropper.style.cursor = 'move'
    @cropper.style.position = 'absolute'
    @imageContainer.appendChild(@cropper)

    # se-resize cursor initialize
    @cropperSeResize.width = @cropperSeResize.height = @cropperSeResizeSize
    cropperSeResizeCtx = @cropperSeResize.getContext('2d')
    cropperSeResizeCtx.fillStyle = 'rgba(0, 0, 0, 0.24)'
    cropperSeResizeCtx.fillRect(0, 0, @cropperSeResizeSize, @cropperSeResizeSize)
    cropperSeResizeCtx.beginPath()
    cropperSeResizeCtx.moveTo(0, 0)
    cropperSeResizeCtx.lineTo(@cropperSeResizeSize, 0)
    cropperSeResizeCtx.lineTo(@cropperSeResizeSize, @cropperSeResizeSize)
    cropperSeResizeCtx.lineTo(0, @cropperSeResizeSize)
    cropperSeResizeCtx.closePath()
    cropperSeResizeCtx.lineWidth = 2
    cropperSeResizeCtx.strokeStyle = 'rgba(255, 255, 255, 0.4)'
    cropperSeResizeCtx.stroke()
    @cropperSeResize.style.cursor = 'se-resize'
    @cropperSeResize.style.position = 'absolute'
    @imageContainer.appendChild(@cropperSeResize)

    @cropperListener()

  # crop listener for cropper movement, cropper resizer movement
  # and souce image movement
  # @param {Boolean} hd option, for cropping-image quality
  # considering high definition picture performance
  cropperListener: (hd = true) ->
    @cropperWidth = ~~@cropperWidth
    @cropperHeight = ~~@cropperHeight
    # sx: @image crop begin x, so sy is @imge crop begin y
    sx = -@imageOffsetLeft + (@cropperOffsetLeft -
      parseFloat(@imageContainer.style.left.slice(0, -2))) / @imageRatio
    sy = -@imageOffsetTop + (@cropperOffsetTop -
      parseFloat(@imageContainer.style.top.slice(0, -2))) / @imageRatio
    # swidth: @imge crop offset width, so is sheight
    swidth = @cropperWidth / @imageRatio
    swidth = @image.width - sx unless sx + swidth <= @image.width
    sheight = @cropperHeight / @imageRatio
    sheight = @image.height - sy unless sy + sheight <= @image.height

    width = if hd then swidth else @cropperWidth
    height = if hd then sheight else @cropperHeight
    @cropper.width = width
    @cropper.height = height
    cropperCtx = @cropper.getContext('2d')
    cropperCtx.drawImage(@image, sx, sy, swidth, sheight, 0, 0,
      width, height)
    cropperBorder = 1
    cropperCtx.save()

    # clean cropper canvas
    @cropperSource.width = width
    @cropperSource.height = height
    cropperSourceCtx = @cropperSource.getContext('2d')
    # add white background, considering transparent picture
    cropperSourceCtx.fillStyle = 'white'
    cropperSourceCtx.fillRect(0, 0, width, height)
    cropperSourceCtx.drawImage(@image, sx, sy, swidth, sheight, 0, 0,
        width, height)

    # round style
    if @cropperRound
      cropperCtx.fillStyle = 'rgba(0, 0, 0, 0.5)'
      cropperCtx.fillRect(0, 0, width, height)
      cropperBuffer = document.createElement('canvas') # for round use
      cropperBuffer.width = width
      cropperBuffer.height = height
      cropperBufferCtx = cropperBuffer.getContext('2d')
      cropperBufferCtx.drawImage(@cropperSource, 0, 0)
      cropperBufferCtx.globalCompositeOperation = 'destination-in'
      if width > height
        radius = height
      else
        radius = width
      radius = radius / 2
      radius = if radius >= 0 then radius else 0
      cropperBufferCtx.arc(width / 2, height / 2, radius, 0,
        Math.PI * 2)
      cropperBufferCtx.fill()
      cropperCtx.drawImage(cropperBuffer, 0, 0)

    # draw cropper border
    cropperCtx.restore()
    cropperCtx.beginPath()
    cropperBorder = Math.ceil(cropperBorder * width / @cropperWidth)
    metaOffset = cropperBorder / 2
    drawWidth = ~~width
    drawHeight = ~~height
    cropperCtx.moveTo(metaOffset, metaOffset)
    cropperCtx.lineTo(drawWidth - metaOffset, metaOffset)
    cropperCtx.lineTo(drawWidth - metaOffset, drawHeight - metaOffset)
    cropperCtx.lineTo(metaOffset, drawHeight - metaOffset)
    cropperCtx.closePath()
    cropperCtx.lineWidth = cropperBorder
    cropperCtx.strokeStyle = 'rgba(255, 255, 255, 0.24)'
    cropperCtx.stroke()

    # crop callback
    @cropCallback?(@cropperSource)

    # cropper position
    @cropper.style.top = "#{@cropperOffsetTop}px"
    @cropper.style.left = "#{@cropperOffsetLeft}px"
    @cropper.style.width = "#{@cropperWidth}px"
    @cropper.style.height = "#{@cropperHeight}px"

    # se-resize cursor position
    @cropperSeResize.style.top = @cropperOffsetTop + @cropperHeight -
      @cropperSeResizeSize / 2 + 'px'
    @cropperSeResize.style.left = @cropperOffsetLeft + @cropperWidth -
      @cropperSeResizeSize / 2 + 'px'

  sourceImageMousedown: (e) ->
    e.preventDefault()
    @imagePrevX = e.clientX or e.targetTouches[0].clientX
    @imagePrevY = e.clientY or e.targetTouches[0].clientY
    @listenTo(document, 'mousemove', @sourceImageMove)
    @listenTo(document, 'touchmove', @sourceImageMove)

  sourceImageMove: (e) ->
    e.preventDefault()
    if @sourceImage.offsetWidth > @containerWidth
      clientX = e.clientX or e.targetTouches[0].clientX
      offsetLeft = clientX - @imagePrevX +
        parseFloat(@sourceImage.style.left.slice(0, -2))
      offsetLeftLimit = @containerWidth - @sourceImage.offsetWidth
      offsetLeft = offsetLeftLimit if offsetLeft < offsetLeftLimit
      offsetLeft = 0 if offsetLeft > 0
      @sourceImage.style.left = "#{offsetLeft}px" if @sourceImage.offsetWidth > @containerWidth
    else
      clientY = e.clientY or e.targetTouches[0].clientY
      offsetTop = clientY - @imagePrevY +
        parseFloat(@sourceImage.style.top.slice(0, -2))
      offsetTopLimit = @containerHeight - @sourceImage.offsetHeight
      offsetTop = offsetTopLimit if offsetTop < offsetTopLimit
      offsetTop = 0 if offsetTop > 0
      @sourceImage.style.top = "#{offsetTop}px" if @sourceImage.offsetHeight > @containerHeight
    @imagePrevX = e.clientX or e.targetTouches[0].clientX
    @imagePrevY = e.clientY or e.targetTouches[0].clientY
    # source image offsets data
    @imageOffsetTop = parseFloat(@sourceImage.style.top.slice(0, -2)) / @imageRatio
    @imageOffsetLeft = parseFloat(@sourceImage.style.left.slice(0, -2)) / @imageRatio
    # cropper listener
    @cropperListener(false)

  cropperMousedown: (e) ->
    e.preventDefault()
    @cropperPrevX = e.clientX or e.targetTouches[0].clientX
    @cropperPrevY = e.clientY or e.targetTouches[0].clientY
    @listenTo(document, 'mousemove', @cropperMove)
    @listenTo(document, 'touchmove', @cropperMove)

  cropperMove: (e) ->
    e.preventDefault()
    clientX = e.clientX or e.targetTouches[0].clientX
    clientY = e.clientY or e.targetTouches[0].clientY
    @cropperOffsetTop =  clientY - @cropperPrevY + @cropper.offsetTop
    @cropperOffsetLeft = clientX - @cropperPrevX + @cropper.offsetLeft

    # top limitation
    if @imageStyleHeight < @containerHeight
      cropperTopMin = (@containerHeight - @imageStyleHeight) / 2
      cropperTopMax = cropperTopMin + @imageStyleHeight - @cropperHeight
    else
      cropperTopMax = @containerHeight - @cropperHeight
      cropperTopMin = 0
    if @cropperOffsetTop > cropperTopMax
      @cropperOffsetTop = cropperTopMax
    if @cropperOffsetTop < cropperTopMin
      @cropperOffsetTop = cropperTopMin

    # left limitation
    if @imageStyleWidth < @containerWidth
      cropperLeftMin = (@containerWidth - @imageStyleWidth) / 2
      cropperLeftMax = cropperLeftMin + @imageStyleWidth - @cropperWidth
    else
      cropperLeftMax = @containerWidth - @cropperWidth
      cropperLeftMin = 0
    if @cropperOffsetLeft > cropperLeftMax
      @cropperOffsetLeft = cropperLeftMax
    if @cropperOffsetLeft < cropperLeftMin
      @cropperOffsetLeft = cropperLeftMin

    @cropperPrevX = e.clientX or e.targetTouches[0].clientX
    @cropperPrevY = e.clientY or e.targetTouches[0].clientY
    @cropperListener(false)

  cropperSeResizeMousedown: (e) ->
    e.preventDefault()
    @cropperResizePrevX = e.clientX or e.targetTouches[0].clientX
    @cropperResizePrevY = e.clientY or e.targetTouches[0].clientY
    @listenTo(document, 'mousemove', @cropperSeResizeMove)
    @listenTo(document, 'touchmove', @cropperSeResizeMove)

  cropperSeResizeMove: (e) ->
    e.preventDefault()

    # limitation
    if @imageStyleWidth < @containerWidth
      widthLimit = @imageStyleWidth / 2 + @containerWidth / 2 -
        @cropperOffsetLeft
    else
      widthLimit = @containerWidth - @cropperOffsetLeft

    if @imageStyleHeight < @containerHeight
      heightLimit = @imageStyleHeight / 2 + @containerHeight / 2 -
        @cropperOffsetTop
    else
      heightLimit = @containerHeight - @cropperOffsetTop

    # when ratio > 1, resize with width, or with height
    if @cropperRatio >= 1
      clientX = e.clientX or e.targetTouches[0].clientX
      @cropperWidth += clientX - @cropperResizePrevX
      @cropperWidth = 0 if @cropperWidth < 0
      @cropperWidth = widthLimit if @cropperWidth > widthLimit
      @cropperHeight = Math.floor(@cropperWidth / @cropperRatio)
      if @cropperHeight > heightLimit
        @cropperHeight = heightLimit
        @cropperWidth = @cropperHeight * @cropperRatio
    else
      clientY = e.clientY or e.targetTouches[0].clientY
      @cropperHeight += clientY - @cropperResizePrevY
      @cropperHeight = 0 if @cropperHeight < 0
      @cropperHeight = heightLimit if @cropperHeight > heightLimit
      @cropperWidth = Math.floor(@cropperHeight * @cropperRatio)
      if @cropperWidth > widthLimit
        @cropperWidth = widthLimit
        @cropperHeight = @cropperWidth / @cropperRatio

    # cropper minimum limitation
    if @cropperWidth < 10
      @cropperWidth = 10
      @cropperHeight = @cropperWidth / @cropperRatio

    @cropperResizePrevX = e.clientX or e.targetTouches[0].clientX
    @cropperResizePrevY = e.clientY or e.targetTouches[0].clientY
    @cropperListener(false)

  # cropped source to a Blob
  toBlob: ->
    croppedCanvas = document.createElement('canvas')
    croppedCanvas.width = @croppedWidth
    croppedCanvas.height = @croppedWidth / @cropperRatio
    croppedCanvas.getContext('2d').drawImage(@cropperSource, 0, 0,
      croppedCanvas.width, croppedCanvas.height)
    dataMIME = 'image/png'
    dataURL = croppedCanvas.toDataURL(dataMIME)
    dataArray = dataURL.split(',')
    dataStr = window.atob(dataArray[1])
    dataLength = dataStr.length
    uint8Data = new Uint8Array(dataLength)
    uint8Data[i] = data.charCodeAt(0) for data, i in dataStr
    return new Blob([uint8Data], {type: dataMIME})

  # cropped base64 data
  toDataURL: ->
    return @cropperSource.toDataURL()

  # remove all events listeners
  destroy: ->
    @stopListening()
