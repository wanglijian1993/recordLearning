# ArkTS装饰器

## Builder装饰器
Builder装饰的函数也叫"自定义构造函数",是一个轻量级ui复用机制。
语法

### 组件内自定义构造函数
`@Builder MyBuilderFunction() { ... }`

### 全局自定义构建函数
`@Builder function MyGlobalBuilderFunction() { ... }`
组件内和全局创建Builder装饰的函数区别就在函数名前面的`function`


## BuilderParam装饰器

## wrapBuilder装饰器
wrapBuilder装饰器，属于模版装饰器，接受全局@Builder自定义组件进行赋值和传递。


@Builder
function MyBuilder(value:string,size:number){

  Text(value)
    .fontSize(size)

}


let gobalBuilder:WrappedBuilder<[string,number]> = wrapBuilder(MyBuilder)

@Preview
@Entry
@Component
struct Index{

  @State message:string='Hello world'

  build() {
    Row() {
      Column() {
        gobalBuilder.builder(this.message,20)
      }
      .width('100%')
    }
    .height('100%')
  }

}

## Style装饰器
Style装饰器，起到封装公共的通用属性和通用事件给控件使用，创建全局Style需要function字段，在组件内声明不需要function,并且不支持传入参数。


@Styles function globalFancy(){
  .width(150)
  .height(100)
  .backgroundColor(Color.Pink)
}

@Entry
@Component
struct FancyUse {

  @State heightValue: number = 100
  // 定义在组件内的@Styles封装的样式
  @Styles fancy() {
    .width(200)
    .height(this.heightValue)
    .backgroundColor(Color.Yellow)
    .onClick(() => {
      this.heightValue = 200
    })
  }

  build() {
    Column({ space: 10 }) {
      // 使用全局的@Styles封装的样式
      Text('FancyA')
        .globalFancy()
        .fontSize(30)
      // 使用组件内的@Styles封装的样式
      Text('FancyB')
        .fancy()
        .fontSize(30)
    }


  }

}

## Extend装饰器
extend装饰器用于扩展原生组件的功能，弥补Style装饰器只能修饰公共参数和功能事件的缺点，Extend装饰器只能用于全局声明。


@Extend(Text) function fancyText(weightValue: number, color: Color) {
  .fontStyle(FontStyle.Italic)
  .fontWeight(weightValue)
  .backgroundColor(color)
}

@Entry
@Component
struct FancyUse {
  @State label: string = 'Hello World'

  build() {
    Row({ space: 10 }) {
      Text(`${this.label}`)
        .fancyText(100, Color.Blue)
      Text(`${this.label}`)
        .fancyText(200, Color.Pink)
      Text(`${this.label}`)
        .fancyText(300, Color.Orange)
    }.margin('20%')
  }
}


## stateStyles装饰器
stateStyles装饰器，根据组件状态的不同去修改组件的样式。
概述
stateStyles是属性方法，可以根据UI内部状态来设置样式，类似于css伪类，但语法不同。ArkUI提供以下五种状态：

focused：获焦态。

normal：正常态。

pressed：按压态。

disabled：不可用态。

selected：选中态。

代码举例
@Preview
@Entry
@Component
struct MyComponent{

  @Styles normalStyle(){
    .backgroundColor(Color.Gray)
  }

  @Styles pressedStyle(){
    .backgroundColor(Color.Red)
  }

  build() {
    Column(){
      Text('Text1')
        .fontSize(50)
        .fontColor(Color.White)
        .stateStyles({
           normal:this.normalStyle,
           pressed:this.pressedStyle
        })
    }
  }

}

## AnimatableExtend装饰器
AnimatableExtend装饰器用于自定义可动画的属性方法，在这个属性方法中修改组件不可动画的属性。在动画执行过程中，通过逐帧回调函数修改不可动画属性值，让不可动画属性也能实现动画属性。
可动画属性:如果一个属性方法在animation属性前调用，改变这个属性的值可以生效animation属性的动画效果，这个属性称为可动画属性。比如height，width，backgroundColor，translate属性，Text组件的fontSzie属性等。
不可动画属性:如果一个属性方法在animation属性前调用，改变这个属性的值不能生效animation属性的动画效果，这个属性称为不可动画属性。比如Polyline组件的points属性等。

@AnimatableExtend(Text) function animatableFontSize(size:number){

  .fontSize(size)

}

@Entry
@Component
struct AnimatablePropertyExample{

  @State fontSize:number=20

  build() {

    Column(){
      Text("AnimatableProperty")
        .animatableFontSize(this.fontSize)
        .animation({duration:1000,curve:"ease"})
      Button("play")
        .onClick(()=>{
          this.fontSize=this.fontSize==20?36:20
        })
        .width("100%")
        .padding(10)
    }

  }
}
## Required装饰器
概述
当@Require装饰器和@Prop或者@BuilderParam结合使用时，在构造该自定义组件时，@Prop和@BuilderParam必须在构造时传参。@Require是校验@Prop或者@BuilderParam是否需要构造传参的一个装饰器。


限制条件
@Require装饰器仅用于装饰struct内的@Prop和@BuilderParam成员状态变量。
