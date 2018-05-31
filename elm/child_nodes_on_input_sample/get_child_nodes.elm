port module Main exposing (..)

import Html exposing (Html, div, text, h1, h2)
import Html.Attributes
import Html.Events
import Json.Encode as Encode
import Json.Decode as Decode exposing (Decoder, string, at, map, field, maybe, andThen, succeed, decodeValue, fail)
import Json.Decode.Pipeline exposing (decode, requiredAt, optionalAt, custom)
type alias Model =
  { content : String
  , loadedContent : String
  }

initialModel : (Model, Cmd msg)
initialModel =
  ({ content = "content"
    , loadedContent = "loadedcontent"
  }, Cmd.none)

type Msg
  = UpdateContent String

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UpdateContent content ->
            ({ model | content = content }, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


contentEditable : Model -> Html Msg
contentEditable model =
    div [] [
        h2 [] [text "The content editable div"]
        , div
            [ Html.Attributes.contenteditable True
            , Html.Events.on "input" (map UpdateContent innerHtmlDecoder)
            , Html.Attributes.attribute "placeholder" "Type here"
            , Html.Attributes.property "innerHTML" (Encode.string model.loadedContent)
            ]
            []
        , h2 [] [text "Output from the content editable div"]
        , div [Html.Attributes.style [("width", "60px")]] [Html.text model.content]
        
    ]

main : Program Never Model Msg
main =
    Html.program
        { init = initialModel
        , subscriptions = subscriptions
        , update = update
        , view = contentEditable
        }


innerHtmlDecoder : Decoder String
innerHtmlDecoder =
    at [ "target" ] (map (\ strList -> String.trim <| String.join "" strList) childNodesDecoder)
    |> debug


childNodesDecoder : Decoder (List String)
childNodesDecoder =
    (field "childNodes" <| loop 0 [] decodeChildNodes)
    |> map List.reverse

-- Ref: https://github.com/debois/elm-dom/blob/master/src/DOM.elm#L111-L122
loop idx xs decoder =
    maybe (field (toString idx) decoder )
        |> andThen
            (Maybe.map (\x -> loop (idx + 1) (x :: xs) decoder)
                >> Maybe.withDefault (succeed xs)
            )

-- In line
decodeChildNodes =
    let
        buildChildNodes =
            \ nodeName data alt childNodes ->
                case nodeName of
                    "#text" ->
                        data
                    "IMG" ->
                        alt
                    "DIV" ->
                        "\n" ++ String.join "" childNodes
                    _ ->
                        ""
    in
        decode buildChildNodes
            |> requiredAt [ "nodeName" ] string
            |> optionalAt [ "data" ] string ""
            |> optionalAt [ "alt" ] string ""
            |> custom ( ( field "childNodes" <| loop 0 [] decodeChildNode) |> map List.reverse)

-- element in one line
decodeChildNode =
    let
        buildChildNode =
            \ nodeName data alt ->
                case nodeName of
                    "#text" ->
                        data
                    "IMG" ->
                        alt
                    _ ->
                        ""
    in
        decode buildChildNode
            |> requiredAt [ "nodeName" ] string
            |> optionalAt [ "data" ] string ""
            |> optionalAt [ "alt" ] string ""


debug : Decoder a -> Decoder a
debug decoder =
  Decode.value
    |> andThen (\value ->
      case decodeValue decoder value of
        Ok val -> succeed val
        Err error -> Debug.log "error" error |> fail
     )



