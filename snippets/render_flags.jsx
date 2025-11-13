export const BazelFlags = () => {
    // const [hue, setHue] = useState(180)
    // const [saturation, setSaturation] = useState(50)
    // const [lightness, setLightness] = useState(50)
    // const [colors, setColors] = useState([])
  
    // useEffect(() => {
    //   const newColors = []
    //   for (let i = 0; i < 5; i++) {
    //     const l = Math.max(10, Math.min(90, lightness - 20 + i * 10))
    //     newColors.push(`hsl(${hue}, ${saturation}%, ${l}%)`)
    //   }
    //   setColors(newColors)
    // }, [hue, saturation, lightness])
  
    // const copyToClipboard = (color) => {
    //   navigator.clipboard
    //     .writeText(color)
    //     .then(() => {
    //       console.log(`Copied ${color} to clipboard!`)
    //     })
    //     .catch((err) => {
    //       console.error("Failed to copy: ", err)
    //     })
    // }
  
    return (
      <div className="p-4 border dark:border-zinc-950/80 rounded-xl not-prose">
        Flag documentation goes here.
      </div>
    )
  }