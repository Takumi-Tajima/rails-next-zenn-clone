import type { NextPage } from 'next'
import SimpleButton from '@/components/SimpleButton'

const HelloWorld: NextPage = () => {
  const handleClick = () => {
    console.log('デンジ')
  }

  return(
    <>
      <h1>og</h1>
      <div className=''>ok</div>
      <SimpleButton text="チェンソーマン" onClick={handleClick} />
    </>
  )
}

export default HelloWorld
